import Foundation

/// Events emitted by `CaptureEngine` over its `AsyncStream`.
enum CaptureEvent: Sendable {
    /// A recovery attempt is starting (1-based attempt number).
    case recoveryAttempt(Int)
    /// Recovery succeeded, the stream is healthy again.
    case recovered
    /// Unrecoverable error: the capture is dead (includes recording-output failures).
    case criticalError(any Error & Sendable)
    /// Health monitor detected a stalled stream (no samples, no file growth).
    case unhealthy(String)
}
