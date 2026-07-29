import Foundation

/// Pure classification of ScreenCaptureKit errors.
enum CaptureErrorClassifier {
    /// ScreenCaptureKit error codes that justify an automatic restart:
    /// - `-3821`: stream stopped by the system (sleep, display change…)
    /// - `-3812`: invalid parameter (transient configuration issue)
    /// - `-3801`: stream configuration error (transient)
    static let recoverableCodes: Set<Int> = [-3821, -3812, -3801]

    static func isRecoverable(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return recoverableCodes.contains(nsError.code)
    }
}
