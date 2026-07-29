import Testing
@testable import MeetingRecorder

@Suite("TeamsWindowClassifier")
struct TeamsWindowClassifierTests {

    @Test("Meeting keywords are detected", arguments: [
        "Team Sync - Meeting",
        "Réunion hebdo",
        "Daily call",
        "Appel client",
        "Conference Room",
        "Conférence produit",
        "Teams Meeting - Project",
        "Video Call with John",
        "Audio Call",
        "Conversation with team",
        "Standup - Microsoft Teams"
    ])
    func meetingWindows(title: String) {
        #expect(TeamsWindowClassifier.isMeetingWindow(title: title))
    }

    @Test("Non-meeting windows are rejected", arguments: [
        "Microsoft Teams Main Window",
        "Fenêtre principale",
        "Chat with Alice",
        "Teams Home",
        "Activity Feed",
        "Calendar",
        "Calendrier",
        "Files",
        "Fichiers partagés",
        "Random Document.txt"
    ])
    func nonMeetingWindows(title: String) {
        #expect(!TeamsWindowClassifier.isMeetingWindow(title: title))
    }

    @Test("Exclude patterns beat meeting keywords")
    func exclusionPriority() {
        // Contains "call" (keyword) but "chat" (exclude) — exclusion wins
        #expect(!TeamsWindowClassifier.isMeetingWindow(title: "Chat: call notes"))
        // Contains "meeting" but also "calendar"
        #expect(!TeamsWindowClassifier.isMeetingWindow(title: "Calendar - Meeting planning"))
    }

    @Test("Matching is case-insensitive")
    func caseInsensitivity() {
        #expect(TeamsWindowClassifier.isMeetingWindow(title: "MEETING NOW"))
        #expect(!TeamsWindowClassifier.isMeetingWindow(title: "CHAT WINDOW"))
    }
}
