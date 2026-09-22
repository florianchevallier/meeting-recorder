import Foundation

/// Composition root: owns the entire object graph of the app.
/// Created once by the AppDelegate; dependencies flow by initializer injection.
@MainActor
struct AppDependencies {
    let settings: SettingsStore
    let permissionMonitor: PermissionMonitor
    let teamsMonitor: TeamsMonitor
    let calendar: CalendarMonitor
    let reminderScheduler: MeetingReminderScheduler
    let coordinator: RecordingCoordinator
    let settingsWindowController: SettingsWindowController
    let statusBarController: StatusBarController
    let onboardingCoordinator: OnboardingCoordinator

    init() {
        let settings = SettingsStore()
        let permissionMonitor = PermissionMonitor()
        let teamsMonitor = TeamsMonitor()
        let calendar = CalendarMonitor(
            source: EventKitCalendarSource(),
            settings: settings,
            permissionMonitor: permissionMonitor
        )
        let coordinator = RecordingCoordinator(
            settings: settings,
            permissionMonitor: permissionMonitor,
            teamsMonitor: teamsMonitor,
            calendar: calendar
        )
        let reminderScheduler = MeetingReminderScheduler(
            calendar: calendar,
            settings: settings,
            onRecord: { coordinator.start() }
        )
        let settingsWindowController = SettingsWindowController(
            settings: settings,
            permissionMonitor: permissionMonitor,
            calendar: calendar
        )
        let statusBarController = StatusBarController(
            coordinator: coordinator,
            permissionMonitor: permissionMonitor,
            calendar: calendar,
            settings: settings,
            settingsWindowController: settingsWindowController
        )
        let onboardingCoordinator = OnboardingCoordinator(
            permissionMonitor: permissionMonitor,
            settingsWindowController: settingsWindowController
        )

        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.teamsMonitor = teamsMonitor
        self.calendar = calendar
        self.reminderScheduler = reminderScheduler
        self.coordinator = coordinator
        self.settingsWindowController = settingsWindowController
        self.statusBarController = statusBarController
        self.onboardingCoordinator = onboardingCoordinator
    }
}
