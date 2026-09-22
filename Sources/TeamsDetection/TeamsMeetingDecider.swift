import Foundation

/// Pure decision: a meeting is active when a meeting window exists AND a Teams
/// process is using the microphone. (`teamsRunning` is handled upstream by
/// the monitor, which resets both signals when Teams quits.)
struct TeamsMeetingDecider {
    struct Input: Equatable, Sendable {
        var hasMeetingWindow: Bool
        var microphoneActive: Bool
    }

    enum Reason: String, Sendable {
        case windowAndMic
        case windowOnly
        case micOnly
        case noSignals
    }

    enum Decision: Equatable, Sendable {
        case active(Reason)
        case inactive(Reason)

        var isActive: Bool {
            if case .active = self { return true }
            return false
        }
    }

    static func decide(for input: Input) -> Decision {
        switch (input.hasMeetingWindow, input.microphoneActive) {
        case (true, true): return .active(.windowAndMic)
        case (true, false): return .inactive(.windowOnly)
        case (false, true): return .inactive(.micOnly)
        case (false, false): return .inactive(.noSignals)
        }
    }
}
