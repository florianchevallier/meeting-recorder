import Foundation

/// Composition root: owns the entire object graph of the app.
/// Created once by the AppDelegate; dependencies flow by initializer injection.
@MainActor
struct AppDependencies {
    let settings: SettingsStore
    let permissionMonitor: PermissionMonitor
    let teamsMonitor: TeamsMonitor
    let coordinator: RecordingCoordinator
    let settingsWindowController: SettingsWindowController
    let statusBarController: StatusBarController
    let onboardingCoordinator: OnboardingCoordinator

    init() {
        let settings = SettingsStore()
        let permissionMonitor = PermissionMonitor()
        let teamsMonitor = TeamsMonitor()
        let coordinator = RecordingCoordinator(settings: settings, teamsMonitor: teamsMonitor)
        let settingsWindowController = SettingsWindowController(
            settings: settings,
            permissionMonitor: permissionMonitor
        )
        let statusBarController = StatusBarController(
            coordinator: coordinator,
            permissionMonitor: permissionMonitor,
            settingsWindowController: settingsWindowController
        )
        let onboardingCoordinator = OnboardingCoordinator(
            permissionMonitor: permissionMonitor,
            settingsWindowController: settingsWindowController
        )

        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.teamsMonitor = teamsMonitor
        self.coordinator = coordinator
        self.settingsWindowController = settingsWindowController
        self.statusBarController = statusBarController
        self.onboardingCoordinator = onboardingCoordinator
    }
}
