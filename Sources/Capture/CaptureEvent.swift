import Foundation

/// Events emitted by `CaptureEngine` over its `AsyncStream`.
enum CaptureEvent: Sendable {
    /// The tap is running and the file is open.
    case started(URL)
    /// The tap is being rebuilt (device change, stall…); the file keeps growing.
    case restarting(attempt: Int, reason: String)
    /// The tap is back.
    case restarted
    /// Quality degraded but recording continues (dropped frames, silent system audio…).
    case degraded(HealthVerdict)
    /// Non-silent system audio reached the tap at least once: the permission is granted.
    case systemAudioDetected
    /// The engine gave up. The file (if any) has been finalized and is playable.
    case failed(CaptureFailure, file: URL?)
}
