import Foundation

/// Recording state machine. Transitions are pure (`transition(_:)`) so the
/// coordinator cannot end up in an impossible state and the matrix is testable.
enum RecordingState: Equatable, Sendable {
    case idle
    case starting
    case recording(startedAt: Date)
    case recovering(startedAt: Date, attempt: Int)
    case stopping

    /// True while a capture session exists (recording or mid-recovery).
    var isRecording: Bool {
        switch self {
        case .recording, .recovering: return true
        case .idle, .starting, .stopping: return false
        }
    }

    var isRecovering: Bool {
        if case .recovering = self { return true }
        return false
    }

    var startedAt: Date? {
        switch self {
        case .recording(let startedAt), .recovering(let startedAt, _): return startedAt
        case .idle, .starting, .stopping: return nil
        }
    }

    enum Action: Equatable, Sendable {
        case startRequested
        case started(Date)
        case startFailed
        case stopRequested
        case stopped
        case restarting(attempt: Int)
        case restarted
        case failed
    }

    /// Returns the next state, or nil when the action is invalid in this state.
    func transition(_ action: Action) -> RecordingState? {
        switch (self, action) {
        case (.idle, .startRequested): return .starting
        case (.starting, .started(let date)): return .recording(startedAt: date)
        case (.starting, .startFailed): return .idle
        case (.starting, .stopRequested): return .stopping
        case (.recording, .stopRequested), (.recovering, .stopRequested): return .stopping
        case (.recording(let startedAt), .restarting(let attempt)),
            (.recovering(let startedAt, _), .restarting(let attempt)):
            return .recovering(startedAt: startedAt, attempt: attempt)
        case (.recovering(let startedAt, _), .restarted): return .recording(startedAt: startedAt)
        case (.recording, .failed), (.recovering, .failed): return .stopping
        case (.stopping, .stopped): return .idle
        default: return nil
        }
    }
}
