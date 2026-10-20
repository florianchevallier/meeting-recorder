import AppKit
import SwiftUI

// MARK: - Permissions Tab

struct PermissionsSettingsTab: View {
    private let permissionMonitor: PermissionMonitor

    init(permissionMonitor: PermissionMonitor) {
        self.permissionMonitor = permissionMonitor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "lock.shield.fill",
                    gradientColors: [.green, .teal],
                    title: L10n.settingsPermissionsHeaderTitle,
                    subtitle: L10n.settingsPermissionsHeaderSubtitle
                )

                SettingsCard {
                    SettingsPermissionRow(
                        title: L10n.permissionMicrophoneTitle,
                        description: L10n.permissionMicrophoneDescription,
                        icon: "mic.fill",
                        status: permissionMonitor.microphone,
                        request: { await permissionMonitor.requestMicrophone() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .microphone) }
                    )

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionSystemAudioTitle,
                        description: L10n.permissionSystemAudioDescription,
                        icon: "speaker.wave.2.circle.fill",
                        status: permissionMonitor.systemAudio,
                        requestTitle: L10n.permissionSystemAudioVerify,
                        request: { await permissionMonitor.requestSystemAudio() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .systemAudio) }
                    )

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionAccessibilityTitle,
                        description: L10n.permissionAccessibilityDescription,
                        icon: "eye.fill",
                        status: permissionMonitor.accessibility,
                        request: { permissionMonitor.requestAccessibility() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .accessibility) }
                    )

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionCalendarTitle,
                        description: L10n.permissionCalendarDescription,
                        icon: "calendar",
                        status: permissionMonitor.calendar,
                        request: { await permissionMonitor.requestCalendar() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .calendar) }
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
    }
}
