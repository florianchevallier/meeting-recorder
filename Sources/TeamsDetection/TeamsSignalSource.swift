import Foundation

// MARK: - Log Detection Result

enum LogDetectionResult: CustomStringConvertible, Sendable {
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

// MARK: - Signal Source Protocol

/// The four raw signals used to detect a Teams meeting.
/// Promoted from the old environment-struct to a protocol for test fakes.
protocol TeamsSignalSource: Sendable {
    func isTeamsRunning() -> Bool
    func readLogState() -> LogDetectionResult
    func hasMeetingWindow() -> Bool
    func isMicrophoneActive() -> Bool
}

// MARK: - Window Classification

struct TeamsWindowClassifier {
    static let meetingKeywords = [
        "meeting", "réunion", "call", "appel",
        "conference", "conférence", "teams meeting",
        "video call", "audio call", "conversation",
        "- Microsoft Teams"
    ]

    static let excludePatterns = [
        "main window", "fenêtre principale",
        "chat", "teams home", "activity",
        "calendar", "calendrier", "files", "fichiers"
    ]

    static func isMeetingWindow(title: String) -> Bool {
        let lowercaseTitle = title.lowercased()

        for excludePattern in excludePatterns {
            if lowercaseTitle.contains(excludePattern.lowercased()) {
                return false
            }
        }

        return meetingKeywords.contains { keyword in
            lowercaseTitle.contains(keyword.lowercased())
        }
    }
}
