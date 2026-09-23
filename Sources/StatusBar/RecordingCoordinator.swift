import os
import Foundation
import Observation

/// User-facing recording error with an optional one-tap remedy.
struct RecordingError: Equatable, Sendable {
    enum Remedy: Equatable, Sendable {
        case openPrivacySettings(PermissionKind)
        case openFolder(URL)

        var title: String {
            switch self {
            case .openPrivacySettings: return L10n.menuErrorOpenPrivacySettings
            case .openFolder: return L10n.menuErrorOpenFolder
            }
        }

        var symbolName: String {
            switch self {
            case .openPrivacySettings: return "gear"
            case .openFolder: return "folder"
            }
        }
    }

    let message: String
    var remedy: Remedy? = nil
}

/// Owns the recording lifecycle: drives the `CaptureEngine` actor, kicks off
/// transcription, and reacts to Teams meeting changes.
@MainActor
@Observable
final class RecordingCoordinator {

    // MARK: - Observable State

    private(set) var state: RecordingState = .idle
    private(set) var error: RecordingError?

    // MARK: - Dependencies

    private let settings: SettingsStore
    private let permissionMonitor: PermissionMonitor
    private let teamsMonitor: TeamsMonitor
    private let calendar: CalendarMonitor?

    /// Transcription entry point.
    let transcription: TranscriptionCoordinator

    // MARK: - Internals

    private var engine: CaptureEngine?
    private var eventsTask: Task<Void, Never>?
    private var teamsEventsTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var permissionWatchTask: Task<Void, Never>?
    /// Calendar event the current recording belongs to (named the file, feeds the sidecar).
    private var sessionEvent: (event: CalendarEvent, startedAt: Date)?

    // MARK: - Computed

    var isRecording: Bool { state.isRecording }
    var isStarting: Bool { state == .starting }
    var isStopping: Bool { state == .stopping }
    /// True whenever a capture session exists or is being created/finalized.
    var hasActiveSession: Bool { state != .idle }
    var recordingStartedAt: Date? { state.startedAt }

    /// Teams meeting currently detected (drives the status bar icon).
    private(set) var isTeamsMeetingDetected = false

    // MARK: - Init

    init(
        settings: SettingsStore,
        permissionMonitor: PermissionMonitor,
        teamsMonitor: TeamsMonitor = TeamsMonitor(),
        calendar: CalendarMonitor? = nil,
        transcription: TranscriptionCoordinator? = nil
    ) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.teamsMonitor = teamsMonitor
        self.calendar = calendar
        self.transcription = transcription ?? TranscriptionCoordinator(settings: settings)
        watchMicrophoneRevocation()
    }

    /// Stops an in-flight recording if the microphone permission is revoked
    /// (macOS applies the revocation live: input goes silent, the app survives).
    private func watchMicrophoneRevocation() {
        let monitor = permissionMonitor
        permissionWatchTask = Task { [weak self] in
            for await denied in Observations({ monitor.microphone == .denied }) where denied {
                guard let self, self.state.isRecording else { continue }
                Log.recording.warning("Microphone permission revoked mid-recording — stopping")
                self.error = RecordingError(
                    message: L10n.errorMicrophonePermission, remedy: .openPrivacySettings(.microphone))
                self.stop()
            }
        }
    }

    // MARK: - Teams Monitoring Lifecycle

    /// Start the Teams monitor and consume its meeting-change stream.
    func startTeamsMonitoring() {
        teamsMonitor.start()
        let changes = teamsMonitor.meetingChanges
        teamsEventsTask = Task { [weak self] in
            for await isActive in changes {
                guard let self else { return }
                self.teamsMeetingDidChange(isActive)
            }
        }
    }

    func stopTeamsMonitoring() {
        teamsEventsTask?.cancel()
        teamsEventsTask = nil
        teamsMonitor.stop()
    }

    // MARK: - State helper

    private func apply(_ action: RecordingState.Action) {
        guard let next = state.transition(action) else {
            Log.recording.warning(
                "Ignored action \(String(describing: action), privacy: .public) in state \(String(describing: self.state), privacy: .public)"
            )
            return
        }
        state = next
    }

    // MARK: - Start

    func start() {
        Log.recording.info("Recording start requested")
        guard state == .idle else {
            Log.recording.warning("Start ignored — state is \(String(describing: self.state), privacy: .public)")
            return
        }
        apply(.startRequested)

        startTask = Task { [weak self] in
            await self?.performStart()
            self?.startTask = nil
        }
    }

    private func performStart() async {
        permissionMonitor.refresh()
        if permissionMonitor.microphone == .notDetermined {
            await permissionMonitor.requestMicrophone()
        }
        guard permissionMonitor.microphone == .granted else {
            Log.recording.error("Missing microphone permission")
            error = RecordingError(message: L10n.errorMicrophonePermission, remedy: .openPrivacySettings(.microphone))
            apply(.startFailed)
            return
        }
        guard permissionMonitor.systemAudio != .denied else {
            Log.recording.error("System audio permission denied")
            error = RecordingError(message: L10n.errorSystemAudioPermission, remedy: .openPrivacySettings(.systemAudio))
            apply(.startFailed)
            return
        }

        let outputURL: URL
        do {
            let documents = try FileSystemUtilities.getDocumentsDirectoryOrThrow()
            guard FileManager.default.isWritableFile(atPath: documents.path) else {
                error = RecordingError(message: L10n.errorOutputFolderNotWritable, remedy: .openFolder(documents))
                apply(.startFailed)
                return
            }
            let startedAt = Date()
            let event = calendar?.isAvailable == true ? calendar?.currentEvent(at: startedAt) : nil
            sessionEvent = event.map { ($0, startedAt) }
            if let event {
                Log.recording.info("Recording matched calendar event \(event.title, privacy: .private)")
            }
            let name = FileSystemUtilities.createTimestampedFilename(
                prefix: Constants.Permissions.recordingPrefix,
                extension: Constants.Permissions.recordingExtension,
                date: startedAt,
                title: event?.title
            )
            outputURL = documents.appendingPathComponent(name)
        } catch {
            self.error = RecordingError(message: L10n.errorRecordingFailed(error.localizedDescription))
            apply(.startFailed)
            return
        }

        let engine = CaptureEngine()
        self.engine = engine
        subscribeToEvents(of: engine)

        do {
            try await engine.start(outputURL: outputURL)
            // A stop may have been requested while the TCC prompt was up.
            guard state == .starting else {
                Log.recording.info("Start completed after a stop request — finalizing immediately")
                await performStop()
                return
            }
            apply(.started(Date()))
            self.error = nil
            Log.recording.info("Recording started")
        } catch {
            Log.recording.error("Recording start failed: \(error.localizedDescription, privacy: .public)")
            if error == .systemAudioAccessDenied {
                permissionMonitor.recordSystemAudioOutcome(.denied)
                self.error = RecordingError(
                    message: L10n.errorSystemAudioPermission, remedy: .openPrivacySettings(.systemAudio))
            } else {
                self.error = RecordingError(
                    message: error.errorDescription ?? L10n.errorRecordingFailed(error.localizedDescription))
            }
            self.engine = nil
            eventsTask?.cancel()
            eventsTask = nil
            apply(.startFailed)
        }
    }

    // MARK: - Stop

    func stop() {
        guard state.isRecording || state == .starting else {
            Log.recording.warning("Stop ignored — state is \(String(describing: self.state), privacy: .public)")
            return
        }
        Log.recording.info("Recording stop requested")
        let wasStarting = state == .starting
        apply(.stopRequested)
        // While starting, `performStart` observes the `.stopping` state and finalizes itself.
        guard !wasStarting else { return }
        stopTask = Task { [weak self] in
            await self?.performStop()
            self?.stopTask = nil
        }
    }

    /// Termination path: stop and finalize (awaited by the AppDelegate).
    func shutdown() async {
        if let startTask { await startTask.value }
        if let stopTask {
            await stopTask.value
            return
        }
        if state.isRecording {
            Log.recording.info("Shutdown while recording — finalizing…")
            apply(.stopRequested)
            await performStop()
        }
    }

    private func performStop() async {
        defer {
            engine = nil
            eventsTask?.cancel()
            eventsTask = nil
            sessionEvent = nil
            calendar?.refresh()
            apply(.stopped)
            Log.recording.info("Stop sequence completed")
        }

        let shouldTranscribe = settings.transcriptionEnabled
        if shouldTranscribe {
            transcription.preIndicate()
        }

        var finalURL: URL?
        do {
            finalURL = try await engine?.stop()
        } catch {
            Log.recording.error("Stop failed: \(error.localizedDescription, privacy: .public)")
            self.error = RecordingError(
                message: (error as? CaptureFailure)?.errorDescription
                    ?? L10n.errorRecordingFailed(error.localizedDescription))
            finalURL = await engine?.recordingURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        }

        handleFinalFile(finalURL, transcribe: shouldTranscribe)
    }

    private func handleFinalFile(_ url: URL?, transcribe: Bool) {
        guard let url else {
            Log.recording.warning("No file generated")
            if transcribe { transcription.notifyNoFileGenerated() }
            return
        }
        Log.recording.info("Final recording saved: \(url.lastPathComponent, privacy: .public)")
        if let sessionEvent {
            do {
                try MeetingMetadata(recordingStartedAt: sessionEvent.startedAt, event: sessionEvent.event)
                    .write(nextTo: url)
            } catch {
                Log.recording.error("Meeting metadata not written: \(error.localizedDescription, privacy: .public)")
            }
        }
        guard transcribe else { return }
        // The sidecar written above gives the transcription its speaker bounds and prompt.
        transcription.enqueue(url)
    }

    // MARK: - Teams Auto-Recording

    /// Auto-starts on meeting begin; recording intentionally continues after the meeting ends.
    func teamsMeetingDidChange(_ isActive: Bool) {
        isTeamsMeetingDetected = isActive
        Log.teams.info("Meeting status changed: \(isActive ? "DETECTED" : "ENDED", privacy: .public)")

        if isActive {
            if settings.autoRecordingEnabled && !isRecording && state == .idle {
                Log.recording.info("Starting automatic recording for Teams meeting")
                start()
            }
        } else {
            Log.recording.info("Teams meeting ended (recording continues)")
        }
    }

    // MARK: - Capture Events

    private func subscribeToEvents(of engine: CaptureEngine) {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            for await event in engine.events {
                guard let self else { return }
                self.handleCaptureEvent(event)
            }
        }
    }

    private func handleCaptureEvent(_ event: CaptureEvent) {
        switch event {
        case .started:
            break

        case .restarting(let attempt, let reason):
            Log.recording.info("Tap restarting (\(attempt)): \(reason, privacy: .public)")
            error = RecordingError(message: L10n.errorRecoveryAttempt(attempt, Constants.Recording.maxRecoveryAttempts))
            apply(.restarting(attempt: attempt))

        case .restarted:
            Log.recording.info("Tap restarted")
            error = nil
            apply(.restarted)

        case .degraded(let verdict):
            Log.recording.warning("Capture degraded: \(String(describing: verdict), privacy: .public)")
            permissionMonitor.refresh()

        case .systemAudioDetected:
            permissionMonitor.recordSystemAudioOutcome(.granted)

        case .failed(let failure, let file):
            Log.recording.error("Capture failed: \(failure.localizedDescription, privacy: .public)")
            if failure == .systemAudioAccessDenied {
                permissionMonitor.recordSystemAudioOutcome(.denied)
                error = RecordingError(
                    message: L10n.errorSystemAudioPermission, remedy: .openPrivacySettings(.systemAudio))
            } else {
                error = RecordingError(message: L10n.errorCriticalRecording(failure.localizedDescription))
            }
            guard state.isRecording else { return }
            apply(.failed)
            engine = nil
            eventsTask?.cancel()
            eventsTask = nil
            // The engine already finalized the file; never transcribe a salvaged recording.
            handleFinalFile(file, transcribe: false)
            apply(.stopped)
        }
    }
}
