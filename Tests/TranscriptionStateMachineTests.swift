import Testing
@testable import MeetingRecorder

@Suite("TranscriptionState machine")
struct TranscriptionStateMachineTests {

    private func reduced(_ state: TranscriptionState, _ event: TranscriptionEvent) -> TranscriptionState {
        var copy = state
        TranscriptionStateReducer.reduce(&copy, event)
        return copy
    }

    @Test("prepare shows the panel without error")
    func prepare() {
        let state = reduced(TranscriptionState(), .prepare)
        #expect(state.isTranscribing)
        #expect(state.error == nil)
        #expect(!state.progress.isEmpty)
    }

    @Test("jobCreated stores the job id and keeps the existing progress message")
    func jobCreatedPreservesProgress() {
        // Real flow: preIndicate → conversion → upload → jobCreated
        var state = reduced(TranscriptionState(), .prepare)
        state = reduced(state, .uploadStarted)
        let uploadMessage = state.progress
        state = reduced(state, .jobCreated("job-123"))

        #expect(state.currentJobId == "job-123")
        #expect(state.isTranscribing)
        #expect(state.progress == uploadMessage) // not overwritten
        #expect(state.error == nil)
    }

    @Test("jobCreated replaces a stale message from a finished run")
    func jobCreatedReplacesStaleProgress() {
        // Without .prepare, isTranscribing is false: the message belongs to a
        // previous run and must be replaced.
        var state = reduced(TranscriptionState(), .uploadStarted)
        state = reduced(state, .jobCreated("job-123"))
        #expect(state.progress == L10n.transcriptionProgressStarted)
    }

    @Test("jobCreated sets a default message when nothing is shown yet")
    func jobCreatedDefaultProgress() {
        let state = reduced(TranscriptionState(), .jobCreated("job-123"))
        #expect(!state.progress.isEmpty)
    }

    @Test("statusUpdated completed stops transcribing")
    func completed() {
        var state = reduced(TranscriptionState(), .jobCreated("job-123"))
        state = reduced(state, .statusUpdated(.completed))
        #expect(!state.isTranscribing)
        #expect(state.status == .completed)
    }

    @Test("failed event sets the error and stops transcribing")
    func failed() {
        var state = reduced(TranscriptionState(), .jobCreated("job-123"))
        state = reduced(state, .failed("boom"))
        #expect(state.error == "boom")
        #expect(!state.isTranscribing)
    }

    @Test("reset clears everything")
    func reset() {
        var state = reduced(TranscriptionState(), .jobCreated("job-123"))
        state = reduced(state, .failed("boom"))
        state = reduced(state, .reset)
        #expect(state == TranscriptionState())
    }

    @Test("saved stops transcribing with a success message")
    func saved() {
        var state = reduced(TranscriptionState(), .jobCreated("job-123"))
        state = reduced(state, .saved)
        #expect(!state.isTranscribing)
        #expect(state.error == nil)
    }
}
