import XCTest
@testable import MeetingRecorder

final class TeamsMeetingDeciderTests: XCTestCase {
    func testExplicitStartWins() {
        let input = TeamsMeetingDecider.Input(
            logResult: .explicitStart,
            hasMeetingWindow: false,
            microphoneActive: false
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .active(let reason):
            XCTAssertEqual(reason, .logExplicitStart)
        default:
            XCTFail("Expected active decision when logs show explicit start")
        }
    }

    func testExplicitEndWins() {
        let input = TeamsMeetingDecider.Input(
            logResult: .explicitEnd,
            hasMeetingWindow: true,
            microphoneActive: true
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .inactive(let reason):
            XCTAssertEqual(reason, .logExplicitEnd)
        default:
            XCTFail("Expected inactive decision when logs show explicit end")
        }
    }

    func testFallbackWindowAndMic() {
        let input = TeamsMeetingDecider.Input(
            logResult: .noEvents,
            hasMeetingWindow: true,
            microphoneActive: true
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .active(let reason):
            XCTAssertEqual(reason, .fallbackWindowAndMic)
        default:
            XCTFail("Expected active decision when both fallback signals are present")
        }
    }

    func testFallbackWindowOnly() {
        let input = TeamsMeetingDecider.Input(
            logResult: .noEvents,
            hasMeetingWindow: true,
            microphoneActive: false
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .inactive(let reason):
            XCTAssertEqual(reason, .fallbackWindowOnly)
        default:
            XCTFail("Expected inactive decision when only meeting window is detected")
        }
    }

    func testFallbackMicrophoneOnly() {
        let input = TeamsMeetingDecider.Input(
            logResult: .noEvents,
            hasMeetingWindow: false,
            microphoneActive: true
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .inactive(let reason):
            XCTAssertEqual(reason, .fallbackMicOnly)
        default:
            XCTFail("Expected inactive decision when only microphone is active")
        }
    }

    func testFallbackNoSignals() {
        let input = TeamsMeetingDecider.Input(
            logResult: .noEvents,
            hasMeetingWindow: false,
            microphoneActive: false
        )

        let decision = TeamsMeetingDecider.decide(for: input)

        switch decision {
        case .inactive(let reason):
            XCTAssertEqual(reason, .fallbackNoSignals)
        default:
            XCTFail("Expected inactive decision when no signals are present")
        }
    }
}
