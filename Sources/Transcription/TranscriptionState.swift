import Foundation

// MARK: - Transcription State (value type)

/// UI-facing state of the transcription pipeline. A plain struct mutated
/// exclusively through `TranscriptionStateReducer` events — fully testable.
struct TranscriptionState: Sendable, Equatable {
    var isTranscribing = false
    var currentJobId: String?
    var status: JobStatus = .pending
    var lastLog: String?
    var progress = ""
    var error: String?
}

// MARK: - Events

enum TranscriptionEvent: Sendable, Equatable {
    /// Pre-indication shown while the recording is being finalized.
    case prepare
    case conversionInProgress
    case uploadStarted
    /// Job created on the server (does not overwrite a more specific progress message).
    case jobCreated(String)
    case statusUpdated(JobStatus)
    case progressMessage(String)
    /// Result downloaded and written next to the recording.
    case saved
    case failed(String)
    case reset
}

// MARK: - Reducer (pure)

enum TranscriptionStateReducer {
    static func reduce(_ state: inout TranscriptionState, _ event: TranscriptionEvent) {
        switch event {
        case .prepare:
            state.isTranscribing = true
            state.error = nil
            applyProgress(&state, L10n.transcriptionProgressPreparing)

        case .conversionInProgress:
            applyProgress(&state, L10n.transcriptionProgressConverting)

        case .uploadStarted:
            applyProgress(&state, L10n.transcriptionProgressUploading)

        case .jobCreated(let jobId):
            // Preserve a more specific progress message if one is already shown
            if state.progress.isEmpty || !state.isTranscribing {
                applyProgress(&state, L10n.transcriptionProgressStarted)
            }
            state.isTranscribing = true
            state.currentJobId = jobId
            state.status = .pending
            state.error = nil

        case .statusUpdated(let newStatus):
            state.status = newStatus
            switch newStatus {
            case .pending:
                applyProgress(&state, L10n.transcriptionProgressPending)
            case .running:
                applyProgress(&state, L10n.transcriptionProgressRunning)
            case .completed:
                applyProgress(&state, L10n.transcriptionProgressCompleted)
                state.isTranscribing = false
            case .failed:
                applyProgress(&state, L10n.transcriptionProgressFailed)
                state.isTranscribing = false
            }

        case .progressMessage(let message):
            applyProgress(&state, message)

        case .saved:
            applyProgress(&state, L10n.transcriptionProgressSaved)
            state.isTranscribing = false

        case .failed(let message):
            state.error = message
            applyProgress(&state, L10n.transcriptionErrorPrefixed(message))
            state.isTranscribing = false

        case .reset:
            state = TranscriptionState()
        }
    }

    private static func applyProgress(_ state: inout TranscriptionState, _ message: String) {
        state.progress = message
        state.lastLog = message
    }
}
