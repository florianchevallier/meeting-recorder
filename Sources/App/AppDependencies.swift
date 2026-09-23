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
    let transcription: TranscriptionCoordinator
    let coordinator: RecordingCoordinator
    let live: LiveTranscriptionCoordinator
    let livePanelController: LiveTranscriptPanelController
    let settingsWindowController: SettingsWindowController
    let speakerNamesWindowController: SpeakerNamesWindowController
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
        let transcription = TranscriptionCoordinator(settings: settings)
        let live = LiveTranscriptionCoordinator(settings: settings)
        let livePanelController = LiveTranscriptPanelController(live: live)
        let coordinator = RecordingCoordinator(
            settings: settings,
            permissionMonitor: permissionMonitor,
            teamsMonitor: teamsMonitor,
            calendar: calendar,
            transcription: transcription,
            live: live
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
        let speakerNamesWindowController = SpeakerNamesWindowController()
        let statusBarController = StatusBarController(
            coordinator: coordinator,
            permissionMonitor: permissionMonitor,
            calendar: calendar,
            settings: settings,
            settingsWindowController: settingsWindowController,
            speakerNamesWindowController: speakerNamesWindowController,
            livePanelController: livePanelController
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
        self.transcription = transcription
        self.coordinator = coordinator
        self.live = live
        self.livePanelController = livePanelController
        self.settingsWindowController = settingsWindowController
        self.speakerNamesWindowController = speakerNamesWindowController
        self.statusBarController = statusBarController
        self.onboardingCoordinator = onboardingCoordinator
    }
}
