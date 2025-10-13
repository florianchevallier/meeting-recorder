import Foundation

/// Encapsulates the pure decision logic that determines whether a Teams meeting
/// is active from the different detection signals.
struct TeamsMeetingDecider {
    struct Input {
        var logResult: LogDetectionResult
        var hasMeetingWindow: Bool
        var microphoneActive: Bool
    }

    enum Reason: String {
        case logExplicitStart
        case logExplicitEnd
        case fallbackWindowAndMic
        case fallbackWindowOnly
        case fallbackMicOnly
        case fallbackNoSignals
    }

    enum Decision {
        case active(Reason)
        case inactive(Reason)
    }

    static func decide(for input: Input) -> Decision {
        switch input.logResult {
        case .explicitStart:
            return .active(.logExplicitStart)
        case .explicitEnd:
            return .inactive(.logExplicitEnd)
        case .noEvents:
            if input.hasMeetingWindow && input.microphoneActive {
                return .active(.fallbackWindowAndMic)
            } else if input.hasMeetingWindow {
                return .inactive(.fallbackWindowOnly)
            } else if input.microphoneActive {
                return .inactive(.fallbackMicOnly)
            } else {
                return .inactive(.fallbackNoSignals)
            }
        }
    }
}
