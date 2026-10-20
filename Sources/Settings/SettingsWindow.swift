import SwiftUI
import AppKit

struct SettingsWindow: View {
    enum SettingsTab: Int {
        case general = 0
        case transcription = 1
        case permissions = 2
        case calendar = 3
        case mcp = 4
    }

    private let settings: SettingsStore
    private let permissionMonitor: PermissionMonitor
    private let calendar: CalendarMonitor
    @Bindable private var model: SettingsWindowModel

    init(
        settings: SettingsStore, permissionMonitor: PermissionMonitor, calendar: CalendarMonitor,
        model: SettingsWindowModel
    ) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.calendar = calendar
        self.model = model
    }

    var body: some View {
        TabView(selection: $model.selectedTab) {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label(L10n.settingsTabGeneral, systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            TranscriptionSettingsTab(settings: settings)
                .tabItem {
                    Label(L10n.settingsTabTranscription, systemImage: "waveform")
                }
                .tag(SettingsTab.transcription)

            CalendarSettingsTab(settings: settings, permissionMonitor: permissionMonitor, calendar: calendar)
                .tabItem {
                    Label(L10n.settingsTabCalendar, systemImage: "calendar")
                }
                .tag(SettingsTab.calendar)

            PermissionsSettingsTab(permissionMonitor: permissionMonitor)
                .tabItem {
                    Label(L10n.settingsTabPermissions, systemImage: "lock.shield")
                }
                .tag(SettingsTab.permissions)

            MCPSettingsTab()
                .tabItem {
                    Label(L10n.settingsTabMcp, systemImage: "sparkles")
                }
                .tag(SettingsTab.mcp)
        }
        .frame(
            minWidth: 520,
            idealWidth: 600,
            maxWidth: 780,
            minHeight: 420,
            idealHeight: 520,
            maxHeight: 720
        )
    }
}
