import os
import Foundation
import Observation

/// First-launch onboarding: opens the Permissions tab until microphone and
/// accessibility are granted, or until the user dismisses the window.
@MainActor
final class OnboardingCoordinator {

    enum Decision: Equatable, Sendable {
        case alreadyComplete
        case complete
        case present
    }

    private let defaults: UserDefaults
    private let permissionMonitor: PermissionMonitor
    private let settingsWindowController: SettingsWindowController
    private var completionTask: Task<Void, Never>?

    init(
        permissionMonitor: PermissionMonitor,
        settingsWindowController: SettingsWindowController,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.permissionMonitor = permissionMonitor
        self.settingsWindowController = settingsWindowController
    }

    /// Pure decision, testable.
    nonisolated static func decide(hasCompleted: Bool, microphone: PermissionStatus, accessibility: PermissionStatus)
        -> Decision
    {
        if hasCompleted { return .alreadyComplete }
        return (microphone == .granted && accessibility == .granted) ? .complete : .present
    }

    func presentIfNeeded() {
        permissionMonitor.refresh()
        let decision = Self.decide(
            hasCompleted: defaults.bool(for: .hasCompletedOnboarding),
            microphone: permissionMonitor.microphone,
            accessibility: permissionMonitor.accessibility
        )
        switch decision {
        case .alreadyComplete:
            return
        case .complete:
            Log.permissions.info("Permissions already granted — onboarding complete")
            markCompleted()
        case .present:
            Log.permissions.info("First launch — presenting permissions onboarding")
            settingsWindowController.onClose = { [weak self] in self?.markCompleted() }
            settingsWindowController.show(tab: .permissions)
            let monitor = permissionMonitor
            completionTask = Task { [weak self] in
                for await satisfied in Observations({ monitor.isOnboardingSatisfied }) where satisfied {
                    self?.markCompleted()
                    return
                }
            }
        }
    }

    func markCompleted() {
        guard !defaults.bool(for: .hasCompletedOnboarding) else { return }
        defaults.set(true, for: .hasCompletedOnboarding)
        settingsWindowController.onClose = nil
        completionTask?.cancel()
        completionTask = nil
        Log.permissions.info("Onboarding marked complete")
    }
}
