import Foundation
import AVFoundation

/// Owns the recording lifecycle: drives the `CaptureEngine` actor, converts the
/// MOV to M4A, kicks off transcription, and reacts to Teams meeting changes.
///
/// Replaces the capture half of the old `StatusBarManager` god object.
@MainActor
@Observable
final class RecordingCoordinator {

    // MARK: - Observable State

    private(set) var state: RecordingState = .idle
    var errorMessage: String?

    // MARK: - Dependencies

    private let settings: SettingsStore
    private let converter: MediaConverter
    private let teamsMonitor: TeamsMonitor

    /// Transcription entry point.
    let transcription: TranscriptionCoordinator

    // MARK: - Internals

    private var engine: CaptureEngine?
    private var eventsTask: Task<Void, Never>?
    private var teamsEventsTask: Task<Void, Never>?

    // MARK: - Computed

    var isRecording: Bool { state.isRecording }
    var isStopping: Bool { state == .stopping }
    var recordingStartedAt: Date? { state.startedAt }

    /// Teams meeting currently detected (drives the status bar icon).
    private(set) var isTeamsMeetingDetected = false

    // MARK: - Init

    init(
        settings: SettingsStore,
        converter: MediaConverter = MediaConverter(),
        teamsMonitor: TeamsMonitor = TeamsMonitor()
    ) {
        self.settings = settings
        self.converter = converter
        self.teamsMonitor = teamsMonitor
        self.transcription = TranscriptionCoordinator(settings: settings)
    }

    // MARK: - Teams Monitoring Lifecycle

    /// Start the Teams monitor and consume its meeting-change stream.
    func startTeamsMonitoring() {
        Task { await teamsMonitor.startMonitoring() }

        teamsEventsTask = Task { [weak self] in
            guard let self else { return }
            for await isActive in teamsMonitor.meetingChanges {
                self.teamsMeetingDidChange(isActive)
            }
        }
    }

    func stopTeamsMonitoring() {
        teamsEventsTask?.cancel()
        teamsEventsTask = nil
        Task { await teamsMonitor.stopMonitoring() }
    }

    func teamsStatus() async -> TeamsStatus {
        await teamsMonitor.status()
    }

    func manualTeamsCheck() async -> Bool {
        await teamsMonitor.checkNow()
    }

    // MARK: - Start

    func start() {
        Logger.shared.info("Recording start requested", component: "RECORDING")

        guard state == .idle else {
            Logger.shared.warning("Start ignored — state is \(state)", component: "RECORDING")
            return
        }
        state = .starting

        Task {
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
                Logger.shared.error("Missing microphone permission", component: "RECORDING")
                errorMessage = L10n.errorMicrophonePermission
                state = .idle
                return
            }

            let engine = CaptureEngine()
            self.engine = engine
            subscribeToEvents(of: engine)

            do {
                _ = try await engine.start()
                state = .recording(startedAt: Date())
                errorMessage = nil
                Logger.shared.info("Recording started successfully", component: "RECORDING")
            } catch {
                Logger.shared.error("Recording start failed: \(error.localizedDescription)", component: "RECORDING")
                errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
                state = .idle
                self.engine = nil
            }
        }
    }

    // MARK: - Stop

    func stop() {
        guard state.isRecording || state == .starting else {
            Logger.shared.warning("Stop ignored — state is \(state)", component: "RECORDING")
            return
        }

        Logger.shared.info("Recording stop requested", component: "RECORDING")
        state = .stopping
        Task { await performStop() }
    }

    /// Termination path: stop and finalize synchronously (awaited by the AppDelegate).
    func shutdown() async {
        if state.isRecording || state == .starting {
            Logger.shared.info("Shutdown while recording — finalizing…", component: "RECORDING")
            state = .stopping
            await performStop()
        }
    }

    private func performStop() async {
        var finalFileURL: URL?

        defer {
            engine = nil
            eventsTask?.cancel()
            eventsTask = nil
            state = .idle
            Logger.shared.info("Stop sequence completed", component: "RECORDING")
        }

        // Pre-indicate transcription (UI feedback before the conversion)
        let shouldTranscribe = settings.transcriptionEnabled
        if shouldTranscribe {
            transcription.preIndicate()
        }

        if let movURL = await engine?.stop() {
            finalFileURL = await convertAndCleanup(movURL: movURL, shouldTranscribe: shouldTranscribe)
        }

        if let finalURL = finalFileURL {
            Logger.shared.info("Final recording saved: \(finalURL.lastPathComponent)", component: "RECORDING")
            if shouldTranscribe {
                Logger.shared.info("Starting transcription for: \(finalURL.lastPathComponent)", component: "TRANSCRIPTION")
                transcription.notifyUploadStarted()
                Task { [transcription] in
                    await transcription.transcribe(audioFileURL: finalURL)
                }
            }
        } else {
            Logger.shared.warning("No file generated", component: "RECORDING")
            if shouldTranscribe {
                transcription.notifyNoFileGenerated()
            }
        }
    }

    /// Convert MOV → M4A and delete the MOV on success.
    /// On conversion failure the MOV is kept and surfaced to the user.
    private func convertAndCleanup(movURL: URL, shouldTranscribe: Bool) async -> URL? {
        do {
            if shouldTranscribe {
                transcription.notifyConversionInProgress()
            }
            let m4aURL = try await converter.convertToM4A(movURL)
            try FileManager.default.removeItem(at: movURL)
            Logger.shared.debug("Original MOV file removed", component: "RECORDING")
            return m4aURL
        } catch {
            Logger.shared.error("MOV to M4A conversion failed: \(error.localizedDescription)", component: "RECORDING")
            errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
            return movURL // keep the MOV as the final artifact
        }
    }

    // MARK: - Teams Auto-Recording

    /// Called when the Teams meeting status flips.
    /// Auto-starts on meeting begin; recording intentionally continues after the meeting ends.
    func teamsMeetingDidChange(_ isActive: Bool) {
        isTeamsMeetingDetected = isActive
        Logger.shared.info("Meeting status changed: \(isActive ? "DETECTED" : "ENDED")", component: "TEAMS")

        if isActive {
            if settings.autoRecordingEnabled && !isRecording {
                Logger.shared.info("Starting automatic recording for Teams meeting", component: "AUTO")
                start()
            }
        } else {
            Logger.shared.info("Teams meeting ended (recording continues)", component: "AUTO")
        }
    }

    // MARK: - Capture Events

    private func subscribeToEvents(of engine: CaptureEngine) {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            for await event in engine.events {
                guard let self else { return }
                handleCaptureEvent(event, engine: engine)
            }
        }
    }

    private func handleCaptureEvent(_ event: CaptureEvent, engine: CaptureEngine) {
        switch event {
        case .recoveryAttempt(let attempt):
            Logger.shared.info("Recovery attempt \(attempt)", component: "RECORDING")
            errorMessage = "Tentative de récupération \(attempt)/\(Constants.Recording.maxRecoveryAttempts)..."
            if case .recording(let startedAt) = state {
                state = .recovering(startedAt: startedAt, attempt: attempt)
            }

        case .recovered:
            Logger.shared.info("Recovery successful", component: "RECORDING")
            errorMessage = nil
            if case .recovering(let startedAt, _) = state {
                state = .recording(startedAt: startedAt)
            }

        case .criticalError(let error):
            Logger.shared.error("Critical capture error: \(error.localizedDescription)", component: "RECORDING")
            errorMessage = "Erreur critique d'enregistrement: \(error.localizedDescription)"
            // Salvage the partial MOV instead of losing it silently
            // (the old code left the timer running and dropped the file).
            Task { [weak self] in
                guard let self else { return }
                if let partialURL = await engine.currentOutputURL,
                   FileManager.default.fileExists(atPath: partialURL.path) {
                    Logger.shared.info("Salvaging partial recording: \(partialURL.lastPathComponent)", component: "RECORDING")
                    _ = await convertAndCleanup(movURL: partialURL, shouldTranscribe: false)
                }
                self.engine = nil
                eventsTask?.cancel()
                eventsTask = nil
                state = .idle
            }

        case .unhealthy(let detail):
            Logger.shared.warning("Capture unhealthy: \(detail)", component: "HEALTH_MONITOR")
        }
    }
}
