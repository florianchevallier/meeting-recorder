import Foundation

// MARK: - Log Detection Result
enum LogDetectionResult: CustomStringConvertible {
    case explicitStart  // Found recent START event without subsequent END
    case explicitEnd    // Found recent END event (more recent than any START)
    case noEvents       // No relevant events found in logs

    var description: String {
        switch self {
        case .explicitStart: return "START"
        case .explicitEnd: return "END"
        case .noEvents: return "NO_EVENTS"
        }
    }
}

@MainActor
final class TeamsDetector: ObservableObject {
    @Published var isTeamsMeetingActive = false
    @Published var lastDetectionTime: Date?

    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = Constants.TeamsDetection.checkInterval

    // Counters to reduce log verbosity
    private var notRunningLogCounter = 0
    private var detectionLogCounter = 0

    private let environment: TeamsDetectionEnvironment
    private let logger: Logger

    private static let defaultBundleIdentifiers = [
        "com.microsoft.teams2",         // New Teams
        "com.microsoft.teams",          // Old Teams
        "com.microsoft.Teams"           // Alternative identifier
    ]

    init(
        environment: TeamsDetectionEnvironment? = nil,
        logger: Logger = .shared
    ) {
        self.logger = logger
        if let environment {
            self.environment = environment
        } else {
            self.environment = TeamsDetectionEnvironment.live(
                logger: logger,
                teamsBundleIdentifiers: Self.defaultBundleIdentifiers
            )
        }
    }

    func startMonitoring() {
        logger.log("🔍 [TEAMS] Starting Teams meeting detection...")

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkTeamsMeetingStatus()
            }
        }
    }

    func stopMonitoring() {
        logger.log("🔍 [TEAMS] Stopping Teams meeting detection")
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func checkTeamsMeetingStatus() async {
        let meetingDetected = detectActiveTeamsMeeting()

        if meetingDetected != isTeamsMeetingActive {
            isTeamsMeetingActive = meetingDetected
            lastDetectionTime = Date()

            logger.log("🔍 [TEAMS] Meeting status changed: \(meetingDetected ? "ACTIVE" : "INACTIVE")")

            NotificationCenter.default.post(
                name: .teamsMeetingStatusChanged,
                object: nil,
                userInfo: ["isActive": meetingDetected]
            )
        }
    }

    // MARK: - Detection Methods

    /// Main detection method combining multiple approaches
    private func detectActiveTeamsMeeting() -> Bool {
        guard environment.isTeamsRunning() else {
            notRunningLogCounter += 1
            if notRunningLogCounter >= Constants.TeamsDetection.logThrottleCount {
                logger.log("🔍 [TEAMS] Teams not running")
                notRunningLogCounter = 0
            }
            return false
        }

        let logResult = environment.readLogState()
        let hasMeetingWindow = environment.hasMeetingWindow()
        let micInUse = environment.isMicrophoneActive()

        detectionLogCounter += 1
        let shouldLogDetails = detectionLogCounter >= Constants.TeamsDetection.logThrottleCount

        if shouldLogDetails {
            logger.log("🔍 [TEAMS] Detection results - Logs: \(logResult.description), Windows: \(hasMeetingWindow ? "✅" : "❌"), Mic: \(micInUse ? "✅" : "❌")")
            detectionLogCounter = 0

            if logResult == .noEvents {
                logger.log("🔍 [TEAMS] No log events found - using fallback detection")
            }
        }

        let decision = TeamsMeetingDecider.decide(
            for: .init(
                logResult: logResult,
                hasMeetingWindow: hasMeetingWindow,
                microphoneActive: micInUse
            )
        )

        if shouldLogDetails {
            logDecision(decision)
        }

        switch decision {
        case .active:
            return true
        case .inactive:
            return false
        }
    }

    private func logDecision(_ decision: TeamsMeetingDecider.Decision) {
        switch decision {
        case .active(let reason):
            logger.log(message(for: reason, isActive: true))
        case .inactive(let reason):
            logger.log(message(for: reason, isActive: false))
        }
    }

    private func message(for reason: TeamsMeetingDecider.Reason, isActive: Bool) -> String {
        switch reason {
        case .logExplicitStart:
            return "🔍 [TEAMS] Explicit START in logs - meeting ACTIVE"
        case .logExplicitEnd:
            return isActive
            ? "🔍 [TEAMS] Unexpected decision state (ACTIVE with END reason)"
            : "🔍 [TEAMS] Explicit END in logs - meeting INACTIVE"
        case .fallbackWindowAndMic:
            return isActive
            ? "🔍 [TEAMS] Meeting window + mic active - meeting ACTIVE"
            : "🔍 [TEAMS] Unexpected decision state (INACTIVE with window + mic)"
        case .fallbackWindowOnly:
            return "🔍 [TEAMS] Meeting window found but no mic activity - meeting POSSIBLY ENDED"
        case .fallbackMicOnly:
            return "🔍 [TEAMS] Mic active but no meeting window - meeting POSSIBLY ENDED"
        case .fallbackNoSignals:
            return isActive
            ? "🔍 [TEAMS] Unexpected decision state (ACTIVE with no signals)"
            : "🔍 [TEAMS] No clear indicators - meeting INACTIVE"
        }
    }

    // MARK: - Public Interface

    /// Manual check for Teams meeting status
    func checkNow() async -> Bool {
        await checkTeamsMeetingStatus()
        return isTeamsMeetingActive
    }

    /// Get current detection status with details
    func getDetectionStatus() -> (isActive: Bool, lastCheck: Date?, method: String) {
        let method = determineLastDetectionMethod()
        return (isTeamsMeetingActive, lastDetectionTime, method)
    }

    private func determineLastDetectionMethod() -> String {
        guard environment.isTeamsRunning() else {
            return "Teams not running"
        }

        let logResult = environment.readLogState()
        let hasWindow = environment.hasMeetingWindow()
        let micActive = environment.isMicrophoneActive()

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

// MARK: - Notification Extensions

extension Notification.Name {
    static let teamsMeetingStatusChanged = Notification.Name("teamsMeetingStatusChanged")
}
