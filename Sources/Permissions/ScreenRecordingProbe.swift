import Foundation
import ScreenCaptureKit
import CoreMedia

/// Functional probe for the Screen Recording permission.
///
/// Stateless and `Sendable`: returns a value instead of mutating published state
/// from an unstructured task (which raced with repeated checks).
struct ScreenRecordingProbe: Sendable {

    enum ProbeResult: Sendable {
        case authorized
        case denied
        case notDetermined
    }

    /// Run the 3-method probe, from cheapest to most authoritative:
    /// 1. `SCShareableContent.excludingDesktopWindows` — non-empty displays means granted
    /// 2. `SCShareableContent.current` — newer API, same signal
    /// 3. Minimal 1×1 stream start/stop — definitive functional test
    ///
    /// Mapping is deliberately conservative: only ScreenCaptureKit errors
    /// -3801 / -3804 map to `.denied`; anything else maps to `.notDetermined`
    /// (transient system states must not be surfaced as a refusal).
    func probe() async -> ProbeResult {
        var lastError: Error?

        // Method 1
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if !content.displays.isEmpty {
                Logger.shared.debug("Screen recording granted (excludingDesktopWindows)", component: "PERMISSIONS")
                return .authorized
            }
        } catch {
            lastError = error
            Logger.shared.debug("excludingDesktopWindows failed: \(error.localizedDescription)", component: "PERMISSIONS")
        }

        // Method 2
        do {
            let content = try await SCShareableContent.current
            if !content.displays.isEmpty {
                Logger.shared.debug("Screen recording granted (SCShareableContent.current)", component: "PERMISSIONS")
                return .authorized
            }
        } catch {
            if lastError == nil { lastError = error }
            Logger.shared.debug("SCShareableContent.current failed: \(error.localizedDescription)", component: "PERMISSIONS")
        }

        // Method 3: minimal test stream
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.width = 1
                config.height = 1
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try await stream.startCapture()
                try await stream.stopCapture()
                Logger.shared.debug("Screen recording granted (test stream)", component: "PERMISSIONS")
                return .authorized
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit" && (nsError.code == -3801 || nsError.code == -3804) {
                Logger.shared.info("Screen recording explicitly denied (code \(nsError.code))", component: "PERMISSIONS")
                return .denied
            }
            if lastError == nil { lastError = error }
            Logger.shared.debug("Test stream failed (non-permission error): \(error.localizedDescription)", component: "PERMISSIONS")
        }

        // Conservative fallback: an explicit permission error from methods 1–2 also maps to denied
        if let error = lastError {
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit" && (nsError.code == -3801 || nsError.code == -3804) {
                return .denied
            }
            Logger.shared.debug("Screen recording probe unclear: \(error.localizedDescription)", component: "PERMISSIONS")
        }
        return .notDetermined
    }

    /// Trigger the system permission prompt by starting/stopping a minimal stream.
    func triggerPermissionPrompt() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.width = 1
                config.height = 1
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try await stream.startCapture()
                try await stream.stopCapture()
            }
        } catch {
            Logger.shared.debug("Screen recording prompt stream failed: \(error.localizedDescription)", component: "PERMISSIONS")
        }
    }
}
