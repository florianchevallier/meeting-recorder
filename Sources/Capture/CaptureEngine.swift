import Foundation
import ScreenCaptureKit

/// The capture engine: owns the `SCStream` + `SCRecordingOutput` lifecycle,
/// the stop finalization handshake, automatic recovery, and health monitoring.
///
/// All mutable capture state lives inside this actor. ScreenCaptureKit delegate
/// callbacks arrive on private queues and are forwarded by `StreamDelegateBridge`.
///
/// Fixes vs the old `UnifiedScreenCapture`:
/// - Health monitoring actually works: the bridge is attached as a lightweight
///   sample-counting `SCStreamOutput` (plus MOV file-growth as a second signal).
/// - Recovery retries directly when a restart fails (no silent give-up).
/// - `recordingOutput(didFailWithError:)` surfaces as `.criticalError`.
/// - The finish continuation is resumed exactly once, inside the actor.
actor CaptureEngine {

    // MARK: - Events

    /// Stream of capture events (recovery, critical errors, health warnings).
    nonisolated let events: AsyncStream<CaptureEvent>
    private let eventContinuation: AsyncStream<CaptureEvent>.Continuation

    // MARK: - State

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var bridge: StreamDelegateBridge?

    private var isRecording = false
    private var isStopping = false
    private var recordingStartTime: Date?
    private var outputURL: URL?
    private var lastStreamDimensions: (width: Int, height: Int)?

    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var finalizationWatcher: Task<Void, Never>?
    private var fallbackElapsed: TimeInterval = 0
    private var fallbackLastSize: UInt64 = 0
    private var fallbackStableCount = 0

    private var retryCount = 0
    private var isRecovering = false
    private var recoveryTask: Task<Void, Never>?

    private var healthTask: Task<Void, Never>?
    private var healthCheckCounter = 0
    private var lastHealthFileSize: UInt64 = 0

    // MARK: - Init

    init() {
        let (stream, continuation) = AsyncStream<CaptureEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
    }

    // MARK: - Public API

    /// URL of the MOV being written (or last written). Lets the coordinator
    /// salvage a partial file after a critical error.
    var currentOutputURL: URL? { outputURL }

    var recordingDuration: TimeInterval {
        guard let recordingStartTime else { return 0 }
        return Date().timeIntervalSince(recordingStartTime)
    }

    /// Start recording. Returns the MOV output URL.
    func start() async throws -> URL {
        guard !isRecording else {
            Logger.shared.warning("Already recording — start ignored", component: "CAPTURE")
            throw CaptureError.alreadyRecording
        }

        Logger.shared.info("Starting unified recording…", component: "CAPTURE")
        retryCount = 0
        isRecovering = false
        outputURL = nil
        recordingStartTime = nil

        try await startInternal()

        guard let outputURL else { throw CaptureError.documentsUnavailable }
        return outputURL
    }

    /// Stop recording with the full finalization handshake.
    /// Returns the finalized MOV URL, or nil if not recording.
    func stop() async -> URL? {
        guard isRecording, let stream else {
            Logger.shared.warning("Not recording — stop ignored", component: "CAPTURE")
            return nil
        }

        Logger.shared.info("Stopping unified recording…", component: "CAPTURE")
        isStopping = true
        defer { isStopping = false }

        // 1. Ask the stream to stop
        do {
            try await stream.stopCapture()
        } catch {
            Logger.shared.error("Error during stopCapture (continuing cleanup): \(error.localizedDescription)", component: "CAPTURE")
        }

        // 2. Wait until SCRecordingOutput has fully written the file
        //    (delegate callback, with a file-stability fallback watcher)
        Logger.shared.info("Waiting for recording output to finish…", component: "CAPTURE")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finishContinuation = continuation
            startFinalizationWatcher()
        }
        finalizationWatcher?.cancel()
        finalizationWatcher = nil

        // 3. Now that writing is finished, detach outputs
        if let recordingOutput {
            do {
                try stream.removeRecordingOutput(recordingOutput)
            } catch {
                Logger.shared.warning("removeRecordingOutput failed: \(error.localizedDescription)", component: "CAPTURE")
            }
        }

        // 4. Teardown
        self.recordingOutput = nil
        self.stream = nil
        self.bridge = nil
        isRecording = false
        stopHealthMonitoring()

        if let recordingStartTime {
            let duration = Date().timeIntervalSince(recordingStartTime)
            Logger.shared.info("Recording stopped. Duration: \(String(format: "%.1f", duration))s", component: "CAPTURE")
        }
        self.recordingStartTime = nil

        Logger.shared.info("Unified recording stopped successfully", component: "CAPTURE")
        return outputURL
    }

    // MARK: - Internal Start (also used by recovery)

    private func startInternal() async throws {
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw CaptureError.noDisplay
        }

        let configuration = CaptureConfiguration.makeStreamConfiguration(display: display)
        let filter = CaptureConfiguration.makeContentFilter(
            display: display,
            applications: availableContent.applications
        )
        lastStreamDimensions = (display.width, display.height)

        if outputURL == nil {
            outputURL = try CaptureConfiguration.makeOutputURL()
        }
        guard let safeOutputURL = outputURL else {
            throw CaptureError.documentsUnavailable
        }

        let bridge = StreamDelegateBridge(engine: self)
        self.bridge = bridge

        let recordingConfiguration = CaptureConfiguration.makeRecordingConfiguration(outputURL: safeOutputURL)
        let newRecordingOutput = SCRecordingOutput(configuration: recordingConfiguration, delegate: bridge)
        recordingOutput = newRecordingOutput

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: bridge)
        stream = newStream

        try newStream.addRecordingOutput(newRecordingOutput)

        // Attach the bridge as a lightweight sample-counting output so health
        // monitoring has a real liveness signal (buffers are discarded).
        try newStream.addStreamOutput(bridge, type: .screen, sampleHandlerQueue: bridge.screenQueue)
        try newStream.addStreamOutput(bridge, type: .audio, sampleHandlerQueue: bridge.audioQueue)
        try newStream.addStreamOutput(bridge, type: .microphone, sampleHandlerQueue: bridge.microphoneQueue)

        try await newStream.startCapture()

        bridge.markStarted()
        isRecording = true
        if recordingStartTime == nil {
            recordingStartTime = Date()
        }
        startHealthMonitoring()

        Logger.shared.info("Unified recording started — Screen + System Audio + Microphone", component: "CAPTURE")
    }

    // MARK: - Finalization Handshake

    /// Fallback watcher: if `recordingOutputDidFinishRecording` never fires,
    /// resume once the MOV size is stable (or after the max wait).
    private func startFinalizationWatcher() {
        finalizationWatcher?.cancel()
        fallbackElapsed = 0
        fallbackLastSize = 0
        fallbackStableCount = 0

        finalizationWatcher = Task { [weak self] in
            guard let self else { return }
            let interval = Constants.Recording.fileStabilityCheckInterval

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }
                if await self.finalizationTick() { return }
            }
        }
    }

    /// One fallback poll step. Returns true when the watcher should stop.
    private func finalizationTick() -> Bool {
        if finishContinuation == nil { return true } // delegate already resumed us

        let interval = Constants.Recording.fileStabilityCheckInterval
        fallbackElapsed += interval

        if let url = outputURL,
           let size = fileSize(at: url) {
            if size > 0 && size == fallbackLastSize {
                fallbackStableCount += 1
            } else {
                fallbackStableCount = 0
                fallbackLastSize = size
            }

            if fallbackStableCount >= Constants.Recording.finalizationStabilityRequiredChecks {
                Logger.shared.info("Fallback: MOV stable, resuming finalization", component: "CAPTURE")
                resumeFinishContinuation()
                return true
            }
        }

        if fallbackElapsed >= Constants.Recording.finalizationMaxWaitTime {
            Logger.shared.warning("Timeout waiting for recording finalization (\(Int(Constants.Recording.finalizationMaxWaitTime))s)", component: "CAPTURE")
            resumeFinishContinuation()
            return true
        }

        return false
    }

    /// Resume the finish continuation exactly once.
    private func resumeFinishContinuation() {
        if let continuation = finishContinuation {
            finishContinuation = nil
            continuation.resume()
        }
    }

    // MARK: - Health Monitoring

    private func startHealthMonitoring() {
        stopHealthMonitoring()
        Logger.shared.debug("Starting stream health monitoring", component: "HEALTH_MONITOR")
        lastHealthFileSize = 0
        healthCheckCounter = 0

        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Constants.Recording.healthCheckInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self?.performHealthCheck()
            }
        }
    }

    private func stopHealthMonitoring() {
        healthTask?.cancel()
        healthTask = nil
    }

    private func performHealthCheck() {
        guard isRecording else { return }

        let stats: (count: Int, lastTime: Date?) = bridge?.sampleStats() ?? (count: 0, lastTime: nil)
        let timeSinceLastSample = stats.lastTime.map { Date().timeIntervalSince($0) } ?? .infinity

        // Second liveness signal: the MOV should keep growing
        let currentSize = outputURL.flatMap { fileSize(at: $0) } ?? 0
        let fileGrowing = currentSize > lastHealthFileSize
        lastHealthFileSize = currentSize

        if timeSinceLastSample > Constants.Recording.healthCheckSampleTimeout && !fileGrowing {
            Logger.shared.warning(
                "No samples for \(Int(timeSinceLastSample))s and file not growing (\(stats.count) samples so far)",
                component: "HEALTH_MONITOR"
            )
            eventContinuation.yield(.unhealthy("No samples for \(Int(timeSinceLastSample))s"))
            Task { await logDetailedStreamHealth() }
        }

        // Stats log once per minute (12 checks × 5s)
        healthCheckCounter += 1
        if healthCheckCounter >= 12 {
            Logger.shared.debug("Stream healthy — \(stats.count) samples received", component: "HEALTH_MONITOR")
            healthCheckCounter = 0
        }
    }

    private func logDetailedStreamHealth() async {
        do {
            let content = try await SCShareableContent.current
            Logger.shared.info("Displays available: \(content.displays.count), applications: \(content.applications.count)", component: "HEALTH_MONITOR")
        } catch {
            Logger.shared.error("Shareable content check failed: \(error.localizedDescription)", component: "HEALTH_MONITOR")
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        Logger.shared.info("Microphone permission: \(micStatus.rawValue)", component: "HEALTH_MONITOR")

        if let defaultMic = AVCaptureDevice.default(for: .audio) {
            Logger.shared.info("Default microphone: \(defaultMic.localizedName), connected: \(defaultMic.isConnected)", component: "HEALTH_MONITOR")
            if !defaultMic.isConnected {
                Logger.shared.warning("MICROPHONE DISCONNECTED", component: "HEALTH_MONITOR")
            }
        } else {
            Logger.shared.warning("NO DEFAULT MICROPHONE AVAILABLE", component: "HEALTH_MONITOR")
        }
    }

    // MARK: - Delegate Entry Points (called by StreamDelegateBridge)

    func streamDidStop(with error: any Error) {
        // Ignore errors triggered by our own stop/teardown
        guard isRecording, !isStopping else { return }

        let nsError = error as NSError
        Logger.shared.error("Stream stopped with error — domain: \(nsError.domain), code: \(nsError.code): \(error.localizedDescription)", component: "CAPTURE")

        // Deep diagnostics for the classic "system stopped the stream" error
        if nsError.code == -3821 {
            let url = outputURL
            let dimensions = lastStreamDimensions
            Task {
                await CaptureDiagnostics.runDeepDiagnostics(outputURL: url, lastStreamDimensions: dimensions)
            }
        }

        if CaptureErrorClassifier.isRecoverable(error), retryCount < Constants.Recording.maxRecoveryAttempts, !isRecovering {
            attemptRecovery()
        } else {
            handleCriticalError(error)
        }
    }

    func recordingOutputDidFail(with error: any Error) {
        // The old code only flipped isRecording internally and never told anyone —
        // the UI stayed stuck in "recording". Now surfaced as a critical error.
        Logger.shared.error("Recording output failed: \(error.localizedDescription)", component: "CAPTURE")
        handleCriticalError(error)
    }

    func recordingDidFinish() {
        Logger.shared.info("Recording output finished — file is ready", component: "CAPTURE")
        finalizationWatcher?.cancel()
        finalizationWatcher = nil
        resumeFinishContinuation()
    }

    // MARK: - Recovery

    private func attemptRecovery() {
        isRecovering = true
        retryCount += 1

        Logger.shared.info("Attempting recovery (\(retryCount)/\(Constants.Recording.maxRecoveryAttempts))", component: "CAPTURE")
        eventContinuation.yield(.recoveryAttempt(retryCount))

        recoveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(Constants.Recording.recoveryDelay * 1_000_000_000))
                try Task.checkCancellation()
                await self.performRecoveryRestart()
            } catch {
                Logger.shared.info("Recovery cancelled", component: "CAPTURE")
            }
        }
    }

    /// One full restart cycle: cleanup → start. Schedules the next attempt
    /// directly on failure (the old code waited for a didStopWithError that
    /// never arrives after a failed startCapture — silently giving up).
    private func performRecoveryRestart() async {
        do {
            await cleanupStream()

            Logger.shared.info("Attempting restart…", component: "CAPTURE")
            try await startInternal()

            Logger.shared.info("Recovery successful", component: "CAPTURE")
            retryCount = 0
            isRecovering = false
            eventContinuation.yield(.recovered)
        } catch {
            Logger.shared.error("Recovery attempt \(retryCount) failed: \(error.localizedDescription)", component: "CAPTURE")
            isRecovering = false

            if retryCount >= Constants.Recording.maxRecoveryAttempts {
                handleCriticalError(error)
            } else {
                attemptRecovery()
            }
        }
    }

    private func handleCriticalError(_ error: any Error) {
        guard isRecording || isRecovering else { return }

        isRecording = false
        isRecovering = false
        retryCount = 0

        Logger.shared.error("Critical error — capture is dead", component: "CAPTURE")

        Task { await cleanupStream() }
        // Sendable-safe payload for the event stream
        eventContinuation.yield(.criticalError(error as NSError))
    }

    private func cleanupStream() async {
        if let stream {
            do {
                try await stream.stopCapture()
            } catch {
                Logger.shared.warning("Error stopping stream during cleanup: \(error.localizedDescription)", component: "CAPTURE")
            }
        }

        stream = nil
        recordingOutput = nil
        bridge = nil
        stopHealthMonitoring()

        finalizationWatcher?.cancel()
        finalizationWatcher = nil
        // Never leave an awaiting stop() hanging: resume, don't drop.
        resumeFinishContinuation()

        isRecording = false
    }

    // MARK: - Helpers

    private nonisolated func fileSize(at url: URL) -> UInt64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.uint64Value
    }
}
