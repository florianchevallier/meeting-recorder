import Foundation
import CoreAudio

/// What the engine should do after a failure.
enum RecoveryPolicy: Sendable, Equatable {
    /// Tear the tap/aggregate down and rebuild it; the writer keeps running.
    case restartTap
    /// Finalize whatever was written and stop.
    case fatal
}

/// Pure classification of capture failures.
enum CaptureErrorClassifier {
    /// Core Audio statuses that are typically transient (device went away,
    /// HAL not ready, format renegotiation after a device switch…).
    static let restartableStatuses: Set<OSStatus> = [
        kAudioHardwareBadDeviceError,  // '!dev'
        kAudioHardwareBadObjectError,  // '!obj'
        kAudioHardwareBadStreamError,  // '!str'
        kAudioHardwareNotRunningError,  // 'stop'
        kAudioHardwareNotReadyError,  // 'nrdy'
        kAudioDeviceUnsupportedFormatError,  // '!dat'
    ]

    static func policy(for failure: CaptureFailure) -> RecoveryPolicy {
        switch failure {
        case .coreAudio(let status, _):
            return restartableStatuses.contains(status) ? .restartTap : .fatal
        case .stalled, .tapUnavailable:
            return .restartTap
        case .noOutputDevice, .noInputDevice, .writer, .diskFull, .documentsUnavailable,
            .alreadyRecording, .notRecording, .systemAudioAccessDenied, .finalizationTimedOut:
            return .fatal
        }
    }
}
