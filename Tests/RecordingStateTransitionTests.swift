import Testing
import Foundation
@testable import MeetingRecorder

@Suite("RecordingState transitions")
struct RecordingStateTransitionTests {
    let date = Date(timeIntervalSince1970: 1_000)

    @Test("Happy path: idle → starting → recording → stopping → idle")
    func happyPath() {
        var state = RecordingState.idle
        state = state.transition(.startRequested)!
        #expect(state == .starting)
        state = state.transition(.started(date))!
        #expect(state == .recording(startedAt: date))
        state = state.transition(.stopRequested)!
        #expect(state == .stopping)
        state = state.transition(.stopped)!
        #expect(state == .idle)
    }

    @Test("Start failure returns to idle")
    func startFailure() {
        #expect(RecordingState.starting.transition(.startFailed) == .idle)
    }

    @Test("Stop while starting goes to stopping; the late start is then invalid")
    func stopWhileStarting() {
        let stopping = RecordingState.starting.transition(.stopRequested)
        #expect(stopping == .stopping)
        #expect(stopping?.transition(.started(date)) == nil)
    }

    @Test("Restart keeps the original start date and updates the attempt")
    func restart() {
        let recording = RecordingState.recording(startedAt: date)
        let recovering = recording.transition(.restarting(attempt: 1))
        #expect(recovering == .recovering(startedAt: date, attempt: 1))
        #expect(recovering?.transition(.restarting(attempt: 2)) == .recovering(startedAt: date, attempt: 2))
        #expect(recovering?.transition(.restarted) == .recording(startedAt: date))
        #expect(recovering?.transition(.stopRequested) == .stopping)
        #expect(recovering?.transition(.failed) == .stopping)
    }

    @Test("Double start and stop from idle are invalid")
    func invalidActions() {
        #expect(RecordingState.starting.transition(.startRequested) == nil)
        #expect(RecordingState.recording(startedAt: date).transition(.startRequested) == nil)
        #expect(RecordingState.idle.transition(.stopRequested) == nil)
        #expect(RecordingState.idle.transition(.stopped) == nil)
        #expect(RecordingState.stopping.transition(.stopRequested) == nil)
    }

    @Test("isRecording covers recording and recovering only")
    func isRecording() {
        #expect(RecordingState.recording(startedAt: date).isRecording)
        #expect(RecordingState.recovering(startedAt: date, attempt: 1).isRecording)
        #expect(!RecordingState.idle.isRecording)
        #expect(!RecordingState.starting.isRecording)
        #expect(!RecordingState.stopping.isRecording)
    }
}
