import XCTest
@testable import MeetingRecorder

@MainActor
final class TeamsDetectorTests: XCTestCase {
    func testCheckNowUpdatesStateFromEnvironment() async {
        let environment = TeamsDetectionEnvironment(
            isTeamsRunning: { true },
            readLogState: { .explicitStart },
            hasMeetingWindow: { false },
            isMicrophoneActive: { false }
        )

        let detector = TeamsDetector(environment: environment)

        let isActive = await detector.checkNow()

        XCTAssertTrue(isActive)
        XCTAssertTrue(detector.isTeamsMeetingActive)
        XCTAssertEqual(detector.getDetectionStatus().method, "Logs (START)")
    }

    func testCheckNowHandlesInactiveSignals() async {
        let environment = TeamsDetectionEnvironment(
            isTeamsRunning: { true },
            readLogState: { .noEvents },
            hasMeetingWindow: { false },
            isMicrophoneActive: { false }
        )

        let detector = TeamsDetector(environment: environment)

        let isActive = await detector.checkNow()

        XCTAssertFalse(isActive)
        XCTAssertFalse(detector.isTeamsMeetingActive)
        XCTAssertEqual(detector.getDetectionStatus().method, "No meeting detected")
    }

    func testTeamsNotRunningResetsActivity() async {
        let environment = TeamsDetectionEnvironment(
            isTeamsRunning: { false },
            readLogState: { .explicitStart },
            hasMeetingWindow: { true },
            isMicrophoneActive: { true }
        )

        let detector = TeamsDetector(environment: environment)

        let isActive = await detector.checkNow()

        XCTAssertFalse(isActive)
        XCTAssertFalse(detector.isTeamsMeetingActive)
        XCTAssertEqual(detector.getDetectionStatus().method, "Teams not running")
    }
}
