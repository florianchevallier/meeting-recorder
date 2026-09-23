import Foundation
import Synchronization
import AVFoundation
import CoreAudio
import os

/// Owns one recording: a `ProcessTapController` that can be rebuilt any number
/// of times (device change, stall) while a single `AudioFileWriter` keeps the
/// file open, plus a health loop. Emits `CaptureEvent`s; the coordinator maps
/// them to UI state.
actor CaptureEngine {

    private enum State: Equatable {
        case idle, running, restarting, stopping, stopped
    }

    nonisolated let events: AsyncStream<CaptureEvent>
    private let eventContinuation: AsyncStream<CaptureEvent>.Continuation

    private var state: State = .idle
    private var tap: ProcessTapController?
    private var writer: AudioFileWriter?
    private let counters = CaptureCounters()
    private var health = HealthEvaluator()
    private var deviceObserver: DeviceChangeObserver?

    private var healthTask: Task<Void, Never>?
    private var deviceTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var stopTask: Task<URL, any Error>?

    private var retryCount = 0
    private var lastDegradation: HealthVerdict = .healthy
    private var systemAudioDetected = false
    /// Tap rebuilds caused by a sample-rate change (capped: see `checkHealth`).
    private var rateRestarts = 0
    private var finalURL: URL?

    init() {
        (events, eventContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    /// The final file location (also valid while recording: the `.partial` sibling is renamed to it on stop).
    var recordingURL: URL? { finalURL }

    // MARK: - Start

    /// Opens `outputURL` (written as `<name>.partial.m4a` until `stop()`) and starts the tap.
    func start(outputURL: URL) async throws(CaptureFailure) {
        guard state == .idle else { throw .alreadyRecording }
        finalURL = outputURL
        let partialURL = Self.partialURL(for: outputURL)
        try? FileManager.default.removeItem(at: partialURL)

        let writer = try AudioFileWriter(outputURL: partialURL, counters: counters)
        try writer.start()
        self.writer = writer

        do {
            try startTap()
        } catch {
            writer.cancel()
            try? FileManager.default.removeItem(at: partialURL)
            self.writer = nil
            throw error
        }

        state = .running
        retryCount = 0
        startDeviceObservation()
        startHealthMonitoring()
        Log.capture.info(
            "Recording started → \(outputURL.lastPathComponent, privacy: .public); devices: \(DeviceChangeObserver.snapshotDescription(), privacy: .public)"
        )
        eventContinuation.yield(.started(outputURL))
    }

    // MARK: - Stop

    /// Finalizes the file and returns its URL. Safe to call twice: the second
    /// caller awaits the same finalization.
    func stop() async throws -> URL {
        if let stopTask { return try await stopTask.value }
        guard state == .running || state == .restarting else { throw CaptureFailure.notRecording }
        state = .stopping

        let task = Task<URL, any Error> { try await self.performStop(failure: nil) }
        stopTask = task
        return try await task.value
    }

    private func performStop(failure: CaptureFailure?) async throws -> URL {
        healthTask?.cancel(); healthTask = nil
        deviceTask?.cancel(); deviceTask = nil
        deviceObserver?.invalidate(); deviceObserver = nil
        restartTask?.cancel()
        await restartTask?.value  // never leave a restart in flight (ghost tap)
        restartTask = nil

        tap?.stop()
        tap = nil

        defer {
            state = .stopped
            eventContinuation.finish()
        }

        guard let writer, let finalURL else { throw failure ?? CaptureFailure.notRecording }
        let url = try await finalize(writer: writer, finalURL: finalURL)
        Log.capture.info(
            "Recording finalized → \(url.lastPathComponent, privacy: .public) (\(writer.writtenDuration, format: .fixed(precision: 1))s)"
        )
        if let failure { throw failure }
        return url
    }

    private func finalize(writer: AudioFileWriter, finalURL: URL) async throws -> URL {
        let partialURL = writer.outputURL
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = try await writer.finish() }
            group.addTask {
                try await Task.sleep(for: .seconds(Constants.Recording.finalizationTimeout))
                writer.cancel()
                throw CaptureFailure.finalizationTimedOut
            }
            try await group.next()
            group.cancelAll()
        }
        try? FileManager.default.removeItem(at: finalURL)
        do {
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
        } catch {
            throw CaptureFailure.writer("rename failed: \(error.localizedDescription)")
        }
        if let activity = writer.voiceActivity {
            do {
                try activity.write(to: RecordingFiles(audio: finalURL).voiceActivity)
            } catch {
                Log.capture.error("Voice activity not written: \(error.localizedDescription, privacy: .public)")
            }
        }
        return finalURL
    }

    // MARK: - Tap lifecycle

    private func startTap() throws(CaptureFailure) {
        guard let writer else { throw .notRecording }
        let tap = ProcessTapController()
        try tap.prepare()

        let systemFormat = tap.streamFormats.first { $0.source == .systemTap }?.format
        let microphoneFormat = tap.streamFormats.first { $0.source == .microphone }?.format
        guard let systemFormat else {
            tap.stop()
            throw .coreAudio(status: kAudioHardwareBadStreamError, operation: "NoTapStream")
        }
        writer.configure(systemFormat: systemFormat, microphoneFormat: microphoneFormat)

        let counters = self.counters
        try tap.run { [counters, writer] inputData, inputTime, now, formats in
            Self.handleIO(
                inputData: inputData, inputTime: inputTime, now: now, formats: formats, counters: counters,
                writer: writer)
        }
        self.tap = tap
        health.reset(expectedSampleRate: systemFormat.sampleRate)
    }

    /// IO path (runs on the tap's IO queue): copy each stream into its own PCM
    /// buffer, update meters/counters, hand off to the writer queue.
    private static func handleIO(
        inputData: UnsafePointer<AudioBufferList>,
        inputTime: UnsafePointer<AudioTimeStamp>,
        now: UnsafePointer<AudioTimeStamp>,
        formats: [ProcessTapController.StreamFormat],
        counters: CaptureCounters,
        writer: AudioFileWriter
    ) {
        counters.ioCallbacks.add(1, ordering: .relaxed)
        counters.lastIOHostTime.store(now.pointee.mHostTime, ordering: .relaxed)

        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        guard !formats.isEmpty else { return }
        let cycleFrames = list.first.map { Int($0.mDataByteSize) / max(1, Int($0.mNumberChannels) * 4) } ?? 0
        counters.ioFrames.add(UInt64(cycleFrames), ordering: .relaxed)

        // Back-pressure: if the writer lags more than a few seconds, drop this cycle.
        if counters.pendingFrames.load(ordering: .relaxed) > Constants.Recording.maxPendingFrames {
            counters.droppedFrames.add(UInt64(cycleFrames), ordering: .relaxed)
            return
        }

        var system: AVAudioPCMBuffer?
        var microphone: AVAudioPCMBuffer?
        var systemPeak: Float = 0
        var microphonePeak: Float = 0

        for stream in formats where stream.bufferIndex < list.count {
            let buffer = list[stream.bufferIndex]
            guard let data = buffer.mData else { continue }
            let channels = Int(buffer.mNumberChannels)
            let frames = Int(buffer.mDataByteSize) / (channels * MemoryLayout<Float>.size)
            guard frames > 0,
                let pcm = AVAudioPCMBuffer(pcmFormat: stream.format, frameCapacity: AVAudioFrameCount(frames)),
                let destination = pcm.floatChannelData?[0]
            else { continue }
            pcm.frameLength = AVAudioFrameCount(frames)
            let sampleCount = frames * channels
            destination.update(from: data.assumingMemoryBound(to: Float.self), count: sampleCount)

            var peak: Float = 0
            let samples = UnsafeBufferPointer(start: destination, count: sampleCount)
            for sample in samples { peak = max(peak, abs(sample)) }

            switch stream.source {
            case .systemTap:
                system = pcm
                systemPeak = max(systemPeak, peak)
            case .microphone:
                microphone = pcm
                microphonePeak = max(microphonePeak, peak)
            }
        }
        counters.recordPeaks(system: systemPeak, microphone: microphonePeak)
        writer.enqueue(system: system, microphone: microphone)
    }

    // MARK: - Restart (device change / stall)

    private func scheduleRestart(reason: String) {
        guard state == .running, restartTask == nil else { return }
        state = .restarting
        retryCount += 1
        let attempt = retryCount
        Log.capture.warning(
            "Restarting tap (\(attempt)/\(Constants.Recording.maxRecoveryAttempts)): \(reason, privacy: .public)")
        eventContinuation.yield(.restarting(attempt: attempt, reason: reason))

        let gapStartHostTime = counters.lastIOHostTime.load(ordering: .relaxed)
        tap?.stop()
        tap = nil

        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.Recording.recoveryDelay))
            guard !Task.isCancelled else { return }
            await self?.performRestart(gapStartHostTime: gapStartHostTime, reason: reason)
        }
    }

    private func performRestart(gapStartHostTime: UInt64, reason: String) {
        defer { restartTask = nil }
        guard state == .restarting else { return }
        do {
            try startTap()
            if gapStartHostTime > 0 {
                let gapNanos = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime() &- gapStartHostTime)
                let gap = min(Double(gapNanos) / 1_000_000_000, Constants.Recording.maxSilenceGapFill)
                writer?.insertSilence(seconds: gap)
            }
            state = .running
            retryCount = 0
            Log.capture.info("Tap restarted; devices: \(DeviceChangeObserver.snapshotDescription(), privacy: .public)")
            eventContinuation.yield(.restarted)
        } catch {
            Log.capture.error("Tap restart failed: \(error.localizedDescription, privacy: .public)")
            if retryCount < Constants.Recording.maxRecoveryAttempts,
                CaptureErrorClassifier.policy(for: error) == .restartTap
            {
                state = .running  // so scheduleRestart accepts the next attempt
                scheduleRestart(reason: "retry after \(error.fourCC)")
            } else {
                fail(with: error)
            }
        }
    }

    private func fail(with failure: CaptureFailure) {
        guard state != .stopping, state != .stopped, stopTask == nil else { return }
        state = .stopping
        let task = Task<URL, any Error> { try await self.performStop(failure: failure) }
        stopTask = task
        Task {
            let url = try? await task.value
            let file = url ?? finalURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            eventContinuation.yield(.failed(failure, file: file))
        }
    }

    // MARK: - Monitoring

    private func startHealthMonitoring() {
        healthTask = Task { [weak self] in
            let interval = Constants.Recording.healthPollInterval
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                // Measured, not nominal: the effective sample rate is frames / real time.
                let now = clock.now
                let elapsed = (now - last) / .seconds(1)
                last = now
                await self?.checkHealth(elapsed: elapsed)
            }
        }
    }

    private func checkHealth(elapsed: TimeInterval) {
        guard state == .running else { return }
        let snapshot = counters.snapshot()
        if !systemAudioDetected, snapshot.systemPeak >= health.silenceThreshold {
            systemAudioDetected = true
            eventContinuation.yield(.systemAudioDetected)
        }
        let verdict = health.evaluate(snapshot, elapsed: elapsed)
        switch verdict {
        case .healthy:
            lastDegradation = .healthy
        case .stalled:
            scheduleRestart(reason: "no IO callback for \(Int(Constants.Recording.healthStallTimeout))s")
        case .sampleRateMismatch(let effective, let expected):
            guard rateRestarts < Constants.Recording.maxSampleRateRestarts else {
                if verdict != lastDegradation {
                    lastDegradation = verdict
                    Log.capture.error("Sample rate still off after \(self.rateRestarts) rebuilds — giving up")
                    eventContinuation.yield(.degraded(verdict))
                }
                return
            }
            rateRestarts += 1
            scheduleRestart(reason: "device runs at \(Int(effective)) Hz, formats built for \(Int(expected)) Hz")
        case .dropping, .systemSilent:
            if verdict != lastDegradation {
                lastDegradation = verdict
                Log.capture.warning("Capture degraded: \(String(describing: verdict), privacy: .public)")
                eventContinuation.yield(.degraded(verdict))
            }
        }
    }

    private func startDeviceObservation() {
        let observer = DeviceChangeObserver()
        observer.start()
        deviceObserver = observer
        let changes = observer.changes
        deviceTask = Task { [weak self] in
            for await change in changes {
                // Coalesce bursts (AirPods emit several notifications per switch).
                try? await Task.sleep(for: .seconds(Constants.Recording.deviceChangeDebounce))
                guard !Task.isCancelled else { return }
                await self?.scheduleRestart(reason: "device change (\(String(describing: change)))")
            }
        }
    }

    // MARK: - Helpers

    static func partialURL(for finalURL: URL) -> URL {
        let base = finalURL.deletingPathExtension().lastPathComponent
        return finalURL.deletingLastPathComponent()
            .appendingPathComponent(base + ".partial")
            .appendingPathExtension(finalURL.pathExtension)
    }
}

private extension CaptureFailure {
    var fourCC: String {
        if case .coreAudio(let status, _) = self { return status.fourCharCode }
        return String(describing: self)
    }
}
