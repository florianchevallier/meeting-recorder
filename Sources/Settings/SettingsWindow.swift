import SwiftUI
import AppKit

struct SettingsWindow: View {
    enum SettingsTab: Int {
        case general = 0
        case transcription = 1
        case permissions = 2
    }

    @ObservedObject private var settings: SettingsManager
    @ObservedObject private var statusBarManager: StatusBarManager
    @State private var selectedTab: SettingsTab

    init(statusBarManager: StatusBarManager, selectedTab: SettingsTab = .general) {
        self._settings = ObservedObject(wrappedValue: SettingsManager.shared)
        self._statusBarManager = ObservedObject(wrappedValue: statusBarManager)
        self._selectedTab = State(initialValue: selectedTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(settings: settings, statusBarManager: statusBarManager)
                .tabItem {
                    Label(L10n.settingsTabGeneral, systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            TranscriptionSettingsTab(settings: settings)
                .tabItem {
                    Label(L10n.settingsTabTranscription, systemImage: "waveform")
                }
                .tag(SettingsTab.transcription)

            PermissionsSettingsTab(permissionManager: PermissionManager.shared)
                .tabItem {
                    Label(L10n.settingsTabPermissions, systemImage: "lock.shield")
                }
                .tag(SettingsTab.permissions)
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

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings: SettingsManager
    private let statusBarManager: StatusBarManager
    @State private var autoRecordingEnabled: Bool

    init(settings: SettingsManager, statusBarManager: StatusBarManager) {
        self._settings = ObservedObject(wrappedValue: settings)
        self.statusBarManager = statusBarManager
        self._autoRecordingEnabled = State(initialValue: statusBarManager.isAutoRecordingEnabled())
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
                        Toggle("", isOn: $autoRecordingEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: autoRecordingEnabled) { _, newValue in
                                statusBarManager.setAutoRecordingEnabled(newValue)
                            }
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

// MARK: - Transcription Tab

private struct TranscriptionSettingsTab: View {
    @ObservedObject private var settings: SettingsManager

    init(settings: SettingsManager) {
        self._settings = ObservedObject(wrappedValue: settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "waveform.circle.fill",
                    gradientColors: [.purple, .pink],
                    title: L10n.settingsTranscriptionHeaderTitle,
                    subtitle: L10n.settingsTranscriptionHeaderSubtitle
                )

                SettingsCard {
                    SettingsField(
                        icon: "link.circle.fill",
                        iconColor: .blue,
                        title: L10n.settingsTranscriptionApiTitle,
                        help: L10n.settingsTranscriptionApiHelp
                    ) {
                        TextField(L10n.settingsTranscriptionApiPlaceholder, text: $settings.apiBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Divider()

                    SettingsField(
                        icon: "cpu.fill",
                        iconColor: .purple,
                        title: L10n.settingsTranscriptionModelTitle,
                        help: L10n.settingsTranscriptionModelHelp
                    ) {
                        Picker("", selection: $settings.whisperModel) {
                            Text("tiny").tag("tiny")
                            Text("base").tag("base")
                            Text("small").tag("small")
                            Text("medium").tag("medium")
                            Text("large-v3").tag("large-v3")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    SettingsField(
                        icon: "globe",
                        iconColor: .green,
                        title: L10n.settingsTranscriptionLanguageTitle,
                        help: L10n.settingsTranscriptionLanguageHelp
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("", selection: $settings.language) {
                                Text("🇫🇷 Français").tag("fr")
                                Text("🇬🇧 English").tag("en")
                                Text("🇪🇸 Español").tag("es")
                                Text("🇩🇪 Deutsch").tag("de")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 200, alignment: .leading)

                            Text(
                                String(
                                    format: L10n.settingsTranscriptionLanguageCodeFormat,
                                    settings.language.uppercased()
                                )
                            )
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    SettingsField(
                        icon: "person.2.fill",
                        iconColor: .orange,
                        title: L10n.settingsTranscriptionSpeakersTitle,
                        help: L10n.settingsTranscriptionSpeakersHelp
                    ) {
                        Stepper(value: $settings.nbSpeaker, in: 1...20) {
                            Text(
                                String(
                                    format: L10n.settingsTranscriptionSpeakersCountFormat,
                                    settings.nbSpeaker,
                                    settings.nbSpeaker > 1 ? "s" : ""
                                )
                            )
                            .font(.system(size: 12, weight: .medium))
                        }
                    }

                    Divider()

                    SettingsField(
                        icon: "speedometer",
                        iconColor: .red,
                        title: L10n.settingsTranscriptionComputeTitle,
                        help: L10n.settingsTranscriptionComputeHelp
                    ) {
                        Picker("", selection: $settings.computeType) {
                            Text("int8 (Apple Silicon)").tag("int8")
                            Text("float16 (GPU NVIDIA)").tag("float16")
                            Text("float32 (CPU)").tag("float32")
                        }
                        .pickerStyle(.radioGroup)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack {
                    Button(L10n.settingsTranscriptionReset) {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Permissions Tab

private struct PermissionsSettingsTab: View {
    @ObservedObject private var permissionManager: PermissionManager

    init(permissionManager: PermissionManager) {
        self._permissionManager = ObservedObject(wrappedValue: permissionManager)
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
                        status: permissionManager.microphonePermission
                    ) {
                        await permissionManager.requestMicrophonePermission()
                    }

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionScreenRecordingTitle,
                        description: L10n.permissionScreenRecordingDescription,
                        icon: "record.circle",
                        status: permissionManager.screenRecordingPermission
                    ) {
                        permissionManager.openScreenRecordingSettings()
                    }

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionDocumentsTitle,
                        description: L10n.permissionDocumentsDescription,
                        icon: "folder.fill",
                        status: permissionManager.documentsPermission
                    ) {
                        await permissionManager.requestDocumentsPermission()
                    }

                    Divider()

                    SettingsPermissionRow(
                        title: L10n.permissionAccessibilityTitle,
                        description: L10n.permissionAccessibilityDescription,
                        icon: "eye.fill",
                        status: permissionManager.accessibilityPermission
                    ) {
                        await permissionManager.requestAccessibilityPermission()
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Shared Components

private struct SettingsHeader: View {
    let icon: String
    let gradientColors: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct SettingRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder var control: Control

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            control
        }
    }
}

private struct SettingsField<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let help: String?
    @ViewBuilder var content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }

            content

            if let help {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SettingsPermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionStatus
    let action: () async -> Void

    @State private var isRequesting = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(status.swiftUIColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(status.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            trailingContent
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch status {
        case .authorized:
            Label {
                Text(status.displayName)
                    .font(.system(size: 12, weight: .semibold))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundColor(.green)

        case .denied, .restricted:
            Button(L10n.onboardingButtonOpenPreferences) {
                openSystemPreferences()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .notDetermined:
            Button {
                isRequesting = true
                Task {
                    await action()
                    isRequesting = false
                }
            } label: {
                if isRequesting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(L10n.onboardingButtonAuthorize)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isRequesting)
        }
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}
