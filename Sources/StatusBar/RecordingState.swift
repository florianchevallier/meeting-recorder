import Foundation

/// Recording state machine. The double-start race is impossible by construction:
/// `start()` is only accepted from `.idle`.
enum RecordingState: Equatable {
    case idle
    case starting
    case recording(startedAt: Date)
    case recovering(startedAt: Date, attempt: Int)
    case stopping

    /// True while a capture session exists (recording or mid-recovery).
    var isRecording: Bool {
        switch self {
        case .recording, .recovering:
            return true
        case .idle, .starting, .stopping:
            return false
        }
    }

    var startedAt: Date? {
        switch self {
        case .recording(let startedAt), .recovering(let startedAt, _):
            return startedAt
        case .idle, .starting, .stopping:
            return nil
        }
    }
}
