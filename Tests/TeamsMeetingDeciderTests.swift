import Testing
@testable import MeetingRecorder

@Suite("TeamsMeetingDecider")
struct TeamsMeetingDeciderTests {

    @Test("Explicit START in logs always wins")
    func explicitStart() {
        for window in [true, false] {
            for mic in [true, false] {
                let decision = TeamsMeetingDecider.decide(
                    for: .init(logResult: .explicitStart, hasMeetingWindow: window, microphoneActive: mic)
                )
                #expect(decision == .active(.logExplicitStart))
            }
        }
    }

    @Test("Explicit END in logs always loses")
    func explicitEnd() {
        for window in [true, false] {
            for mic in [true, false] {
                let decision = TeamsMeetingDecider.decide(
                    for: .init(logResult: .explicitEnd, hasMeetingWindow: window, microphoneActive: mic)
                )
                #expect(decision == .inactive(.logExplicitEnd))
            }
        }
    }

    @Test("Window + mic without log events means active")
    func fallbackWindowAndMic() {
        let decision = TeamsMeetingDecider.decide(
            for: .init(logResult: .noEvents, hasMeetingWindow: true, microphoneActive: true)
        )
        #expect(decision == .active(.fallbackWindowAndMic))
    }

    @Test("Window alone is not enough")
    func fallbackWindowOnly() {
        let decision = TeamsMeetingDecider.decide(
            for: .init(logResult: .noEvents, hasMeetingWindow: true, microphoneActive: false)
        )
        #expect(decision == .inactive(.fallbackWindowOnly))
    }

    @Test("Mic alone is not enough")
    func fallbackMicOnly() {
        let decision = TeamsMeetingDecider.decide(
            for: .init(logResult: .noEvents, hasMeetingWindow: false, microphoneActive: true)
        )
        #expect(decision == .inactive(.fallbackMicOnly))
    }

    @Test("No signals means inactive")
    func fallbackNoSignals() {
        let decision = TeamsMeetingDecider.decide(
            for: .init(logResult: .noEvents, hasMeetingWindow: false, microphoneActive: false)
        )
        #expect(decision == .inactive(.fallbackNoSignals))
    }
}
