import Testing
@testable import MeetingRecorder

@Suite("IconState")
struct IconStateTests {
    @Test("Finishing wins over recording, which wins over Teams")
    func priority() {
        #expect(IconState(isStopping: true, isRecording: true, isTeamsMeetingDetected: true) == .finishing)
        #expect(IconState(isStopping: false, isRecording: true, isTeamsMeetingDetected: true) == .recording)
        #expect(IconState(isStopping: false, isRecording: false, isTeamsMeetingDetected: true) == .teamsDetected)
        #expect(IconState(isStopping: false, isRecording: false, isTeamsMeetingDetected: false) == .ready)
    }

    @Test("Every state has a distinct symbol")
    func symbols() {
        let names = IconState.allCases.map(\.symbolName)
        #expect(Set(names).count == names.count)
    }
}
