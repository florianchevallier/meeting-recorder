import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices

/// Monitors the four permissions Meety needs: microphone, screen recording,
/// Documents folder, and accessibility (Teams window detection).
///
/// Replaces `PermissionManager` (ObservableObject/@Published) with `@Observable`.
/// The screen-recording probe is delegated to the stateless `ScreenRecordingProbe`
/// and its result applied on the main actor — no unstructured task mutation.
@MainActor
@Observable
final class PermissionMonitor {

    // MARK: - State

    private let accessibilityPromptedKey = "PermissionManager.accessibilityPrompted" // keep old key: preserves user state

    var microphonePermission: PermissionStatus = .notDetermined
    var screenRecordingPermission: PermissionStatus = .notDetermined
    var documentsPermission: PermissionStatus = .notDetermined
    var accessibilityPermission: PermissionStatus = .notDetermined

    private let screenProbe = ScreenRecordingProbe()
    private var screenProbeTask: Task<Void, Never>?
    private var accessibilityMonitorTask: Task<Void, Never>?
    private var appActiveObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        checkAllPermissions()

        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Re-check everything when the app reactivates
            // (user may have toggled a switch in System Settings)
            Task { @MainActor in
                self?.checkAllPermissions()
            }
        }
    }

    private var hasPromptedAccessibility: Bool {
        get { UserDefaults.standard.bool(forKey: accessibilityPromptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessibilityPromptedKey) }
    }

    // MARK: - Check All

    func checkAllPermissions() {
        checkMicrophonePermission()
        checkScreenRecordingPermission()
        checkDocumentsPermission()
        checkAccessibilityPermission()
    }

    // MARK: - Microphone

    func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
        checkMicrophonePermission()
    }

    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermission = PermissionStatus(from: status)
    }

    // MARK: - Screen Recording

    func requestScreenRecordingPermission() async {
        await screenProbe.triggerPermissionPrompt()
        checkScreenRecordingPermission()
    }

    func checkScreenRecordingPermission() {
        screenProbeTask?.cancel()
        screenProbeTask = Task { [weak self] in
            let result = await ScreenRecordingProbe().probe()
            guard !Task.isCancelled else { return }
            self?.screenRecordingPermission = PermissionStatus(from: result)
        }
    }

    // MARK: - Documents Folder

    func requestDocumentsPermission() async {
        // No standard system prompt exists for Documents; access is implicit.
        // We simply verify it with a functional write/delete test.
        checkDocumentsPermission()
    }

    func checkDocumentsPermission() {
        guard let documentsURL = FileSystemUtilities.getDocumentsDirectory() else {
            Logger.shared.error("Documents directory unavailable", component: "PERMISSIONS")
            documentsPermission = .denied
            return
        }

        let testFileURL = documentsURL.appendingPathComponent(Constants.Permissions.permissionTestFilename)

        var hasPermission = false
        do {
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            hasPermission = true
        } catch {
            Logger.shared.warning("Documents write test failed: \(error.localizedDescription)", component: "PERMISSIONS")
        }

        documentsPermission = hasPermission ? .authorized : .denied
    }

    // MARK: - Accessibility

    func requestAccessibilityPermission() async {
        hasPromptedAccessibility = true

        // Trigger the system prompt.
        // Note: literal key instead of kAXTrustedCheckOptionPrompt — the C global
        // is not concurrency-safe under Swift 6 (same string value).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        openAccessibilitySettings()
        checkAccessibilityPermission()
        startAccessibilityStatusMonitor()
    }

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        let hasWindowAccess = trusted || testWindowAccess()

        if trusted {
            hasPromptedAccessibility = true
        }

        let newStatus: PermissionStatus
        if hasWindowAccess {
            newStatus = .authorized
        } else if hasPromptedAccessibility {
            newStatus = .denied
        } else {
            newStatus = .notDetermined
        }

        if accessibilityPermission != newStatus {
            Logger.shared.info(
                "Accessibility status: \(newStatus.rawValue) (trusted=\(trusted), windowAccess=\(hasWindowAccess))",
                component: "PERMISSIONS"
            )
        }

        accessibilityPermission = newStatus
    }

    /// Functional probe: can we actually read another app's windows (like Teams detection does)?
    private func testWindowAccess() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        guard let finderApp = runningApps.first else {
            // Fallback: probe any running app
            let allApps = NSWorkspace.shared.runningApplications
            guard let testApp = allApps.first(where: { $0.bundleIdentifier != nil }) else {
                return false
            }
            return testAppWindowAccess(app: testApp)
        }
        return testAppWindowAccess(app: finderApp)
    }

    private func testAppWindowAccess(app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        return result == .success
    }

    private func startAccessibilityStatusMonitor() {
        accessibilityMonitorTask?.cancel()
        accessibilityMonitorTask = Task { [weak self] in
            for _ in 0..<Constants.Permissions.accessibilityMonitorAttempts {
                if Task.isCancelled { return }

                if AXIsProcessTrusted() {
                    self?.accessibilityPermission = .authorized
                    return
                }

                try? await Task.sleep(nanoseconds: UInt64(Constants.Permissions.accessibilityMonitorInterval * 1_000_000_000))
            }

            if self?.hasPromptedAccessibility == true {
                self?.accessibilityPermission = .denied
            } else {
                self?.accessibilityPermission = .notDetermined
            }
        }
    }

    // MARK: - Open System Settings

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)

        // Recheck a few times while the user toggles the switch
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Constants.Permissions.recheckDelay * 1_000_000_000))
            for _ in 0..<Constants.Permissions.recheckCount {
                if Task.isCancelled { return }
                self?.checkScreenRecordingPermission()
                try? await Task.sleep(nanoseconds: UInt64(Constants.Permissions.recheckInterval * 1_000_000_000))
            }
        }
    }

    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        // macOS 15: navigate System Settings directly to the Accessibility pane
        let script = """
            tell application "System Settings"
                activate
                reveal anchor "Privacy_Accessibility" of pane id "com.apple.preference.security"
            end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if error == nil { return }
        }

        // Fallback: plain URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Request All

    func requestAllPermissions() async {
        await requestMicrophonePermission()
        await requestScreenRecordingPermission()
        await requestDocumentsPermission()
        await requestAccessibilityPermission()

        checkAllPermissions()
    }

    // MARK: - Computed

    var allPermissionsGranted: Bool {
        microphonePermission == .authorized &&
        screenRecordingPermission == .authorized &&
        documentsPermission == .authorized &&
        accessibilityPermission == .authorized
    }
}

// MARK: - ProbeResult Mapping

private extension PermissionStatus {
    init(from result: ScreenRecordingProbe.ProbeResult) {
        switch result {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        }
    }
}
