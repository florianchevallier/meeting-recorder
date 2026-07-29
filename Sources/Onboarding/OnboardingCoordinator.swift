import Foundation

/// Minimal first-launch onboarding: opens the settings window on the
/// Permissions tab until every permission has been granted.
///
/// The old flow's completion flag was never set (its view was dead code),
/// so the window reappeared on every launch. Completion is now recorded
/// as soon as all four permissions are granted.
@MainActor
final class OnboardingCoordinator {

    private let defaults: UserDefaults
    private let permissionMonitor: PermissionMonitor
    private let settingsWindowController: SettingsWindowController

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding" // keep old key: preserves user state

    init(
        permissionMonitor: PermissionMonitor,
        settingsWindowController: SettingsWindowController,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.permissionMonitor = permissionMonitor
        self.settingsWindowController = settingsWindowController
    }

    var shouldShowOnboarding: Bool {
        !defaults.bool(forKey: hasCompletedOnboardingKey)
    }

    /// Show the permissions tab on first launch. When everything is already
    /// granted, mark onboarding as completed instead of nagging.
    func presentIfNeeded() {
        guard shouldShowOnboarding else { return }

        permissionMonitor.checkAllPermissions()
        if permissionMonitor.allPermissionsGranted {
            Logger.shared.info("All permissions granted — onboarding complete", component: "ONBOARDING")
            markCompleted()
            return
        }

        Logger.shared.info("First launch — presenting permissions onboarding", component: "ONBOARDING")
        settingsWindowController.show(tab: .permissions)
    }

    /// Called when permissions change; completes onboarding once all are granted.
    func completeWhenReady() {
        guard shouldShowOnboarding, permissionMonitor.allPermissionsGranted else { return }
        markCompleted()
    }

    func markCompleted() {
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }
}
