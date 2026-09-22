import os
import Foundation
import AppKit
import AVFAudio
import ApplicationServices

// MARK: - Probes

/// Cheap, synchronous, side-effect-free reads plus explicit request actions.
/// Injected so the monitor's logic is unit-testable.
protocol PermissionProbes: Sendable {
    func microphoneStatus() -> PermissionStatus
    func requestMicrophone() async -> Bool
    func isAccessibilityTrusted() -> Bool
    /// Shows the system Accessibility prompt (idempotent).
    func promptAccessibility()
}

struct SystemPermissionProbes: PermissionProbes {
    func microphoneStatus() -> PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptAccessibility() {
        // Literal key instead of kAXTrustedCheckOptionPrompt: the C global is not
        // concurrency-safe under Swift 6 (same string value).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

/// Runs the deterministic system-audio check (see `SystemAudioPermissionProbe`).
protocol SystemAudioAccessProbing: Sendable {
    func run() async -> SystemAudioPermissionProbe.Outcome
}

extension SystemAudioPermissionProbe: SystemAudioAccessProbing {}

// MARK: - Monitor

/// Tracks the three permissions. `refresh()` is synchronous and cheap; the only
/// asynchronous work is the explicit requests. Refresh triggers are events
/// (app activation, System Settings (de)activation) plus a short, bounded
/// recheck after a deep link into System Settings.
@MainActor
@Observable
final class PermissionMonitor {

    private(set) var microphone: PermissionStatus = .notDetermined
    private(set) var systemAudio: PermissionStatus = .unknownUntilFirstUse
    private(set) var accessibility: PermissionStatus = .notDetermined

    /// True while the system-audio probe (and its TCC prompt) is running.
    private(set) var isProbingSystemAudio = false

    @ObservationIgnored private let probes: any PermissionProbes
    @ObservationIgnored private let systemAudioProbe: (any SystemAudioAccessProbing)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var recheckTask: Task<Void, Never>?

    init(
        probes: any PermissionProbes = SystemPermissionProbes(),
        systemAudioProbe: (any SystemAudioAccessProbing)? = SystemAudioPermissionProbe(),
        defaults: UserDefaults = .standard
    ) {
        self.probes = probes
        self.systemAudioProbe = systemAudioProbe
        self.defaults = defaults
        refresh()
    }

    // MARK: Lifecycle

    /// Registers the event-driven refresh triggers. Call once at launch.
    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
            observers.append(
                workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    guard app?.bundleIdentifier == "com.apple.systempreferences" else { return }
                    MainActor.assumeIsolated { self?.refresh() }
                })
        }
    }

    func stop() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
        recheckTask?.cancel()
        recheckTask = nil
    }

    // MARK: Refresh

    /// Synchronous re-read of every status. Never prompts, never blocks.
    func refresh() {
        let mic = probes.microphoneStatus()
        let trusted = probes.isAccessibilityTrusted()
        if trusted { defaults.set(true, for: .accessibilityPrompted) }
        let axStatus: PermissionStatus =
            trusted
            ? .granted
            : (defaults.bool(for: .accessibilityPrompted) ? .denied : .notDetermined)
        let audio: PermissionStatus
        if !defaults.bool(for: .systemAudioPrompted) {
            audio = .unknownUntilFirstUse
        } else {
            audio = defaults.bool(for: .systemAudioVerified) ? .granted : .denied
        }

        if mic != microphone { microphone = mic }
        if axStatus != accessibility { accessibility = axStatus }
        if audio != systemAudio { systemAudio = audio }
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .microphone: return microphone
        case .systemAudio: return systemAudio
        case .accessibility: return accessibility
        }
    }

    // MARK: Requests

    func requestMicrophone() async {
        if microphone == .notDetermined {
            _ = await probes.requestMicrophone()
        }
        refresh()
    }

    /// Prompts, then deep-links to the Accessibility pane (the prompt alone is easy to miss).
    func requestAccessibility() {
        defaults.set(true, for: .accessibilityPrompted)
        probes.promptAccessibility()
        refresh()
        if accessibility != .granted {
            openSystemSettings(for: .accessibility)
        }
    }

    /// Runs the tone probe: the first call triggers the TCC prompt; later calls
    /// re-verify after the user toggles the switch.
    func requestSystemAudio() async {
        guard let systemAudioProbe, !isProbingSystemAudio else { return }
        isProbingSystemAudio = true
        defer { isProbingSystemAudio = false }
        switch await systemAudioProbe.run() {
        case .audioReceived:
            recordSystemAudioOutcome(.granted)
        case .silence:
            recordSystemAudioOutcome(.denied)
        case .failed(let failure):
            Log.permissions.warning("System audio probe failed: \(failure.localizedDescription, privacy: .public)")
            recordSystemAudioOutcome(failure == .systemAudioAccessDenied ? .denied : .indeterminate)
        }
        if systemAudio == .denied {
            openSystemSettings(for: .systemAudio)
        }
    }

    /// Called by the recording pipeline when it learns something definitive.
    func recordSystemAudioOutcome(_ outcome: SystemAudioOutcome) {
        switch outcome {
        case .granted:
            defaults.set(true, for: .systemAudioPrompted)
            defaults.set(true, for: .systemAudioVerified)
        case .denied:
            defaults.set(true, for: .systemAudioPrompted)
            defaults.set(false, for: .systemAudioVerified)
        case .indeterminate:
            break
        }
        refresh()
    }

    /// Opens the relevant Privacy pane and rechecks for a short while, so the
    /// row updates even if the user never brings Meety back to the front.
    func openSystemSettings(for kind: PermissionKind) {
        NSWorkspace.shared.open(kind.settingsURL)
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            for _ in 0..<Constants.Permissions.recheckCount {
                try? await Task.sleep(for: .seconds(Constants.Permissions.recheckInterval))
                guard !Task.isCancelled, let self else { return }
                self.refresh()
                if self.status(for: kind) == .granted { return }
            }
        }
    }

    // MARK: Derived

    /// Microphone granted and system audio not known to be denied.
    var isRecordingAllowed: Bool {
        microphone == .granted && systemAudio != .denied
    }

    /// Onboarding completes on microphone + accessibility; system audio can only
    /// be granted by recording (or the Verify button), so it must not block.
    var isOnboardingSatisfied: Bool {
        microphone == .granted && accessibility == .granted
    }

    var blockers: [PermissionKind] {
        var result: [PermissionKind] = []
        if microphone != .granted { result.append(.microphone) }
        if systemAudio == .denied { result.append(.systemAudio) }
        return result
    }
}
