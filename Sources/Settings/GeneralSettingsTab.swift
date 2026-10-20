import AppKit
import SwiftUI

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Bindable private var settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "gearshape.fill",
                    gradientColors: [.blue, .cyan],
                    title: L10n.settingsGeneralHeaderTitle,
                    subtitle: L10n.settingsGeneralHeaderSubtitle
                )

                SettingsCard {
                    SettingRow(
                        icon: "video.fill",
                        iconColor: .blue,
                        title: L10n.settingsGeneralAutoRecordingTitle,
                        subtitle: L10n.settingsGeneralAutoRecordingSubtitle
                    ) {
                        Toggle("", isOn: $settings.autoRecordingEnabled)
                            .toggleStyle(.switch)
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingRow(
                        icon: "arrow.up.forward.app.fill",
                        iconColor: .blue,
                        title: L10n.settingsGeneralAutoJoinTitle,
                        subtitle: L10n.settingsGeneralAutoJoinSubtitle
                    ) {
                        Toggle("", isOn: $settings.autoJoinMeetings)
                            .toggleStyle(.switch)
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingRow(
                        icon: "text.bubble.fill",
                        iconColor: .purple,
                        title: L10n.settingsGeneralTranscriptionTitle,
                        subtitle: L10n.settingsGeneralTranscriptionSubtitle
                    ) {
                        Toggle("", isOn: $settings.transcriptionEnabled)
                            .toggleStyle(.switch)
                    }

                    if settings.transcriptionEnabled {
                        Divider()
                            .padding(.leading, 52)

                        SettingRow(
                            icon: "calendar.badge.checkmark",
                            iconColor: .purple,
                            title: L10n.settingsGeneralTranscriptionOnlyMeetingTitle,
                            subtitle: L10n.settingsGeneralTranscriptionOnlyMeetingSubtitle
                        ) {
                            Toggle("", isOn: $settings.transcriptionOnlyWithMeeting)
                                .toggleStyle(.switch)
                        }
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingRow(
                        icon: "captions.bubble.fill",
                        iconColor: .pink,
                        title: L10n.settingsGeneralLiveTitle,
                        subtitle: L10n.settingsGeneralLiveSubtitle
                    ) {
                        Toggle("", isOn: $settings.liveTranscriptionEnabled)
                            .toggleStyle(.switch)
                    }
                }

                SettingsCard {
                    SettingRow(
                        icon: "power",
                        iconColor: .red,
                        title: L10n.settingsGeneralQuitTitle,
                        subtitle: L10n.settingsGeneralQuitSubtitle
                    ) {
                        Button(L10n.actionQuit) {
                            NSApp.terminate(nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
    }
}
