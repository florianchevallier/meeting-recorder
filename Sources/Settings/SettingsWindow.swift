import SwiftUI
import AppKit

struct SettingsWindow: View {
    enum SettingsTab: Int {
        case general = 0
        case transcription = 1
        case permissions = 2
        case calendar = 3
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
                        icon: "text.bubble.fill",
                        iconColor: .purple,
                        title: L10n.settingsGeneralTranscriptionTitle,
                        subtitle: L10n.settingsGeneralTranscriptionSubtitle
                    ) {
                        Toggle("", isOn: $settings.transcriptionEnabled)
                            .toggleStyle(.switch)
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

// MARK: - Transcription Tab

private struct TranscriptionSettingsTab: View {
    @Bindable private var settings: SettingsStore
    @State private var apiURLDraft: String
    @State private var apiKeyDraft: String
    @State private var glossaryDraft: String

    init(settings: SettingsStore) {
        self.settings = settings
        self._apiURLDraft = State(initialValue: settings.apiBaseURL)
        self._apiKeyDraft = State(
            initialValue: KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount) ?? "")
        self._glossaryDraft = State(initialValue: settings.transcriptionGlossary)
    }

    private var isDraftValid: Bool {
        apiURLDraft.isEmpty || SettingsStore.isValidAPIURL(apiURLDraft)
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
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(L10n.settingsTranscriptionApiPlaceholder, text: $apiURLDraft)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .onSubmit { settings.apiBaseURL = apiURLDraft }
                                // Debounced write: one UserDefaults update per pause, not per keystroke.
                                .task(id: apiURLDraft) {
                                    try? await Task.sleep(for: .milliseconds(400))
                                    guard !Task.isCancelled, isDraftValid else { return }
                                    settings.apiBaseURL = apiURLDraft
                                }

                            if !isDraftValid {
                                Text(L10n.settingsTranscriptionApiInvalid)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Divider()

                    SettingsField(
                        icon: "key.fill",
                        iconColor: .gray,
                        title: L10n.settingsTranscriptionApiKeyTitle,
                        help: L10n.settingsTranscriptionApiKeyHelp
                    ) {
                        SecureField(L10n.settingsTranscriptionApiKeyPlaceholder, text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            // Debounced write: one keychain update per pause, not per keystroke.
                            .task(id: apiKeyDraft) {
                                try? await Task.sleep(for: .milliseconds(400))
                                guard !Task.isCancelled else { return }
                                let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard
                                    trimmed != KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount) ?? ""
                                else { return }
                                KeychainStore.set(trimmed, for: KeychainStore.transcriptionAPIKeyAccount)
                            }
                    }

                    Divider()

                    SettingsField(
                        icon: "text.book.closed.fill",
                        iconColor: .teal,
                        title: L10n.settingsTranscriptionGlossaryTitle,
                        help: L10n.settingsTranscriptionGlossaryHelp
                    ) {
                        TextField(L10n.settingsTranscriptionGlossaryPlaceholder, text: $glossaryDraft, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .task(id: glossaryDraft) {
                                try? await Task.sleep(for: .milliseconds(400))
                                guard !Task.isCancelled else { return }
                                settings.transcriptionGlossary = glossaryDraft
                            }
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

// MARK: - Calendar Tab

private struct CalendarSettingsTab: View {
    @Bindable private var settings: SettingsStore
    private let permissionMonitor: PermissionMonitor
    private let calendar: CalendarMonitor

    init(settings: SettingsStore, permissionMonitor: PermissionMonitor, calendar: CalendarMonitor) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.calendar = calendar
    }

    /// Calendars grouped by account, in the source's order.
    private var accounts: [(name: String, calendars: [CalendarInfo])] {
        var result: [(name: String, calendars: [CalendarInfo])] = []
        for info in calendar.calendars {
            if result.last?.name == info.account {
                result[result.count - 1].calendars.append(info)
            } else {
                result.append((info.account, [info]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "calendar",
                    gradientColors: [.red, .orange],
                    title: L10n.settingsCalendarHeaderTitle,
                    subtitle: L10n.settingsCalendarHeaderSubtitle
                )

                SettingsCard {
                    SettingsPermissionRow(
                        title: L10n.permissionCalendarTitle,
                        description: L10n.permissionCalendarDescription,
                        icon: "calendar",
                        status: permissionMonitor.calendar,
                        request: { await permissionMonitor.requestCalendar() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .calendar) }
                    )
                }

                SettingsCard {
                    SettingRow(
                        icon: "calendar.badge.checkmark",
                        iconColor: .red,
                        title: L10n.settingsCalendarEnabledTitle,
                        subtitle: L10n.settingsCalendarEnabledSubtitle
                    ) {
                        Toggle("", isOn: $settings.calendarEnabled)
                            .toggleStyle(.switch)
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingRow(
                        icon: "bell.badge.fill",
                        iconColor: .orange,
                        title: L10n.settingsCalendarRemindersTitle,
                        subtitle: L10n.settingsCalendarRemindersSubtitle
                    ) {
                        Toggle("", isOn: $settings.calendarRemindersEnabled)
                            .toggleStyle(.switch)
                    }
                    .disabled(!settings.calendarEnabled)

                    if settings.calendarRemindersEnabled {
                        Divider()
                            .padding(.leading, 52)

                        SettingRow(
                            icon: "clock.fill",
                            iconColor: .orange,
                            title: L10n.settingsCalendarLeadTitle,
                            subtitle: L10n.settingsCalendarLeadMinutes(settings.calendarReminderLeadMinutes)
                        ) {
                            Stepper(
                                "",
                                value: $settings.calendarReminderLeadMinutes,
                                in: 0...30
                            )
                            .labelsHidden()
                        }
                        .disabled(!settings.calendarEnabled)
                    }
                }

                if settings.calendarEnabled, !calendar.calendars.isEmpty {
                    SettingsCard {
                        Label {
                            Text(L10n.settingsCalendarPickerTitle)
                                .font(.system(size: 14, weight: .medium))
                        } icon: {
                            Image(systemName: "checklist")
                                .foregroundColor(.red)
                        }

                        Text(L10n.settingsCalendarPickerHelp)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        ForEach(accounts, id: \.name) { account in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(account.name.isEmpty ? L10n.settingsCalendarPickerOtherAccount : account.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                ForEach(account.calendars) { info in
                                    Toggle(
                                        isOn: Binding(
                                            get: { calendar.isSelected(info) },
                                            set: { _ in calendar.toggle(info) }
                                        )
                                    ) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(
                                                    info.color.map {
                                                        Color(red: $0.red, green: $0.green, blue: $0.blue)
                                                    } ?? .gray
                                                )
                                                .frame(width: 10, height: 10)
                                            Text(info.title)
                                                .font(.system(size: 13))
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                    }
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
    var requestTitle: String = L10n.onboardingButtonAuthorize
    let request: () async -> Void
    let openSettings: () -> Void

    @State private var isRequesting = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(status.swiftUIColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(status.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailingContent
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch status {
        case .granted:
            Label {
                Text(status.displayName)
                    .font(.system(size: 12, weight: .semibold))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(.green)

        case .denied:
            Button(L10n.onboardingButtonOpenPreferences, action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)

        case .notDetermined, .unknownUntilFirstUse:
            Button {
                isRequesting = true
                Task {
                    await request()
                    isRequesting = false
                }
            } label: {
                if isRequesting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(requestTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isRequesting)
        }
    }
}
