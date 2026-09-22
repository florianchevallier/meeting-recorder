import Testing
@testable import MeetingRecorder

@Suite("TeamsMeetingDecider")
struct TeamsMeetingDeciderTests {

    @Test("Window + mic means active")
    func windowAndMic() {
        let decision = TeamsMeetingDecider.decide(for: .init(hasMeetingWindow: true, microphoneActive: true))
        #expect(decision == .active(.windowAndMic))
        #expect(decision.isActive)
    }

    @Test("Window alone is not enough")
    func windowOnly() {
        #expect(
            TeamsMeetingDecider.decide(for: .init(hasMeetingWindow: true, microphoneActive: false))
                == .inactive(.windowOnly))
    }

    @Test("Mic alone is not enough")
    func micOnly() {
        #expect(
            TeamsMeetingDecider.decide(for: .init(hasMeetingWindow: false, microphoneActive: true))
                == .inactive(.micOnly))
    }

    @Test("No signals means inactive")
    func noSignals() {
        let decision = TeamsMeetingDecider.decide(for: .init(hasMeetingWindow: false, microphoneActive: false))
        #expect(decision == .inactive(.noSignals))
        #expect(!decision.isActive)
    }

    @Test(
        "Teams bundle identifiers",
        arguments: [
            ("com.microsoft.teams2", true), ("com.microsoft.teams", true), ("com.microsoft.Teams", true),
            ("com.microsoft.teams2.helper", true), ("com.apple.finder", false), (nil, false),
        ])
    func bundleIdentifiers(bundleID: String?, expected: Bool) {
        #expect(TeamsApp.isTeams(bundleIdentifier: bundleID) == expected)
    }
}
