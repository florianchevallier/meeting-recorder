import Foundation

/// Detailed snapshot of the detection state (for UI / debugging).
struct TeamsStatus: Sendable {
    var isActive: Bool
    var lastCheck: Date?
    var method: String
}

/// Polls the Teams detection signals every 2 seconds and emits meeting-state
/// changes over an `AsyncStream` (replaces the old NotificationCenter posting).
///
/// Runs as an actor: AX / CoreAudio probes execute off the main thread.
actor TeamsMonitor {

    // MARK: - Events

    /// Emits `true` when a meeting starts, `false` when it ends (changes only).
    nonisolated let meetingChanges: AsyncStream<Bool>
    private let meetingContinuation: AsyncStream<Bool>.Continuation

    // MARK: - State

    private let signals: any TeamsSignalSource
    private var monitoringTask: Task<Void, Never>?
    private var isMeetingActive = false
    private var lastDetectionTime: Date?
    private var checkCounter = 0

    // MARK: - Init

    init(signals: any TeamsSignalSource = LiveTeamsSignalSource()) {
        self.signals = signals
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.meetingChanges = stream
        self.meetingContinuation = continuation
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        Logger.shared.info("Starting Teams meeting detection", component: "TEAMS")

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkTeamsMeetingStatus()
                try? await Task.sleep(nanoseconds: UInt64(Constants.TeamsDetection.checkInterval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        Logger.shared.info("Stopping Teams meeting detection", component: "TEAMS")
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    // MARK: - Public Queries

    /// Manual one-shot check. Returns the current meeting state.
    func checkNow() -> Bool {
        checkTeamsMeetingStatus()
        return isMeetingActive
    }

    func status() -> TeamsStatus {
        TeamsStatus(
            isActive: isMeetingActive,
            lastCheck: lastDetectionTime,
            method: determineLastDetectionMethod()
        )
    }

    // MARK: - Detection

    private func checkTeamsMeetingStatus() {
        let meetingDetected = detectActiveTeamsMeeting()

        if meetingDetected != isMeetingActive {
            isMeetingActive = meetingDetected
            lastDetectionTime = Date()
            Logger.shared.info("Meeting status changed: \(meetingDetected ? "ACTIVE" : "INACTIVE")", component: "TEAMS")
            meetingContinuation.yield(meetingDetected)
        }
    }

    private func detectActiveTeamsMeeting() -> Bool {
        guard signals.isTeamsRunning() else {
            return false
        }

        let logResult = signals.readLogState()
        let hasMeetingWindow = signals.hasMeetingWindow()
        let micInUse = signals.isMicrophoneActive()

        // Throttled detail log (every 30 checks ≈ 1 minute)
        checkCounter += 1
        let shouldLogDetails = checkCounter >= Constants.TeamsDetection.logThrottleCount
        if shouldLogDetails {
            checkCounter = 0
            Logger.shared.debug(
                "Detection — logs: \(logResult.description), window: \(hasMeetingWindow), mic: \(micInUse)",
                component: "TEAMS"
            )
        }

        let decision = TeamsMeetingDecider.decide(
            for: .init(
                logResult: logResult,
                hasMeetingWindow: hasMeetingWindow,
                microphoneActive: micInUse
            )
        )

        if shouldLogDetails {
            switch decision {
            case .active(let reason):
                Logger.shared.debug("Decision: ACTIVE (\(reason.rawValue))", component: "TEAMS")
            case .inactive(let reason):
                Logger.shared.debug("Decision: INACTIVE (\(reason.rawValue))", component: "TEAMS")
            }
        }

        switch decision {
        case .active:
            return true
        case .inactive:
            return false
        }
    }

    private func determineLastDetectionMethod() -> String {
        guard signals.isTeamsRunning() else {
            return "Teams not running"
        }

        let logResult = signals.readLogState()
        let hasWindow = signals.hasMeetingWindow()
        let micActive = signals.isMicrophoneActive()

        switch logResult {
        case .explicitStart:
            return hasWindow ? "Logs + Window" : "Logs (START)"
        case .explicitEnd:
            return "Logs (END)"
        case .noEvents:
            if hasWindow && micActive { return "Window + Audio" }
            if hasWindow { return "Window only" }
            if micActive { return "Audio only" }
            return "No meeting detected"
        }
    }
}
