import XCTest
@testable import MeetingRecorder

final class TeamsWindowClassifierTests: XCTestCase {
    func testIdentifiesMeetingTitles() {
        let titles = [
            "Daily Meeting - Microsoft Teams",
            "Réunion hebdomadaire",
            "Sprint planning video call"
        ]

        for title in titles {
            XCTAssertTrue(TeamsWindowClassifier.isMeetingWindow(title: title), "Expected '\(title)' to be recognised as meeting window")
        }
    }

    func testIgnoresNonMeetingTitles() {
        let titles = [
            "Teams Main Window",
            "Chat with Alice",
            "Calendar - Microsoft Teams",
            "Files"
        ]

        for title in titles {
            XCTAssertFalse(TeamsWindowClassifier.isMeetingWindow(title: title), "Expected '\(title)' to be ignored as non-meeting window")
        }
    }
}
