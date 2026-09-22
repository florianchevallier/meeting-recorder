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
    /// Server-side progress (0…100) parsed from the job log, when it reports one.
    var percent: Int?
    var error: String?
}

// MARK: - Job log parsing

enum TranscriptionProgress {
    /// Server log lines look like `[2026-09-22T20:41:27.559Z] [40%] - Transcription...`:
    /// returns the message without the timestamp and the percentage, if any.
    static func parse(_ log: String) -> (message: String, percent: Int?) {
        var message = log.trimmingCharacters(in: .whitespaces)
        if message.hasPrefix("["), let close = message.firstIndex(of: "]"),
            message[message.index(after: message.startIndex)..<close].contains("T")
        {
            message = message[message.index(after: close)...].trimmingCharacters(in: .whitespaces)
        }
        guard let match = message.firstMatch(of: /^\[(\d{1,3})%\]\s*-?\s*/), let value = Int(match.1) else {
            return (message, nil)
        }
        let rest = message[match.range.upperBound...].trimmingCharacters(in: .whitespaces)
        return (rest.isEmpty ? message : rest, min(value, 100))
    }
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
            state.percent = nil
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
            state.percent = nil
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

        case .progressMessage(let log):
            let parsed = TranscriptionProgress.parse(log)
            applyProgress(&state, parsed.message)
            if let percent = parsed.percent { state.percent = percent }

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
