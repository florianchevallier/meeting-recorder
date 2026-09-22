import Foundation

// MARK: - Signal Events

/// The three raw signals behind Teams meeting detection, delivered as events.
enum TeamsSignalEvent: Sendable, Equatable {
    /// At least one Teams process is running.
    case teamsRunning(Bool)
    /// A Teams window whose title classifies as a meeting exists.
    case meetingWindow(Bool)
    /// A Teams process currently has microphone input running.
    case microphone(Bool)
}

// MARK: - Signal Source Protocol

/// Event-driven source of `TeamsSignalEvent`s. `start()` must emit the current
/// snapshot of every signal first; the stream ends when `stop()` is called.
/// The live implementation composes NSWorkspace, Core Audio and Accessibility
/// observers; tests drive a fake.
protocol TeamsSignalSource: Sendable {
    @MainActor func start() -> AsyncStream<TeamsSignalEvent>
    @MainActor func stop()
}

// MARK: - Teams identification

enum TeamsApp {
    /// New Teams (`com.microsoft.teams2`), classic Teams and helper processes.
    static func isTeams(bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.lowercased().hasPrefix("com.microsoft.teams") ?? false
    }
}

// MARK: - Window Classification

struct TeamsWindowClassifier {
    static let meetingKeywords = [
        "meeting", "réunion", "call", "appel",
        "conference", "conférence", "teams meeting",
        "video call", "audio call", "conversation",
        "- Microsoft Teams", "| Microsoft Teams",
    ]

    static let excludePatterns = [
        "main window", "fenêtre principale",
        "chat", "teams home", "activity",
        "calendar", "calendrier", "files", "fichiers",
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
