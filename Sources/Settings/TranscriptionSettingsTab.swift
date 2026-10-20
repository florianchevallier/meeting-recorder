import AppKit
import SwiftUI

// MARK: - Transcription Tab

struct TranscriptionSettingsTab: View {
    @Bindable private var settings: SettingsStore
    @State private var apiURLDraft: String
    @State private var apiKeyDraft: String
    @State private var glossaryDraft: String
    /// The server is set up once: shown as a summary as soon as its URL is valid.
    @State private var isEditingServer: Bool
    @State private var showsAdvanced = false

    init(settings: SettingsStore) {
        self.settings = settings
        self._apiURLDraft = State(initialValue: settings.apiBaseURL)
        self._apiKeyDraft = State(
            initialValue: KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount) ?? "")
        self._glossaryDraft = State(initialValue: settings.transcriptionGlossary)
        self._isEditingServer = State(initialValue: !SettingsStore.isValidAPIURL(settings.apiBaseURL))
    }

    private var isDraftValid: Bool {
        apiURLDraft.isEmpty || SettingsStore.isValidAPIURL(apiURLDraft)
    }

    private var trimmedAPIKey: String {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
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

                if isEditingServer {
                    serverEditor
                } else {
                    serverSummary
                }

                essentials

                DisclosureGroup(isExpanded: $showsAdvanced) {
                    TranscriptionAdvancedSection(settings: settings)
                        .padding(.top, 12)
                } label: {
                    Text(L10n.settingsTranscriptionAdvancedTitle)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
        // Reset changes the glossary behind the draft.
        .onChange(of: settings.transcriptionGlossary) { _, newValue in
            if newValue != glossaryDraft { glossaryDraft = newValue }
        }
    }

    // MARK: Server

    private var serverSummary: some View {
        SettingsCard {
            SettingRow(
                icon: "server.rack",
                iconColor: .blue,
                title: L10n.settingsTranscriptionServerTitle,
                subtitle: settings.apiBaseURL + " · "
                    + (trimmedAPIKey.isEmpty
                        ? L10n.settingsTranscriptionServerNoKey : L10n.settingsTranscriptionServerKeySet)
            ) {
                Button(L10n.settingsTranscriptionServerEdit) {
                    isEditingServer = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var serverEditor: some View {
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
                        saveAPIKey()
                    }
            }

            HStack {
                Spacer()
                Button(L10n.settingsTranscriptionServerDone) {
                    settings.apiBaseURL = apiURLDraft
                    saveAPIKey()
                    isEditingServer = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!SettingsStore.isValidAPIURL(apiURLDraft))
            }
        }
    }

    private func saveAPIKey() {
        guard trimmedAPIKey != KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount) ?? "" else {
            return
        }
        KeychainStore.set(trimmedAPIKey, for: KeychainStore.transcriptionAPIKeyAccount)
    }

    // MARK: Essentials

    private var essentials: some View {
        SettingsCard {
            SettingsField(
                icon: "globe",
                iconColor: .green,
                title: L10n.settingsTranscriptionLanguageTitle,
                help: L10n.settingsTranscriptionLanguageHelp
            ) {
                Picker("", selection: $settings.language) {
                    Text("🇫🇷 Français").tag("fr")
                    Text("🇬🇧 English").tag("en")
                    Text("🇪🇸 Español").tag("es")
                    Text("🇩🇪 Deutsch").tag("de")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200, alignment: .leading)
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
                        guard !Task.isCancelled, glossaryDraft != settings.transcriptionGlossary else { return }
                        settings.transcriptionGlossary = glossaryDraft
                    }
            }

            Divider()

            SettingsField(
                icon: "square.stack.3d.up.fill",
                iconColor: .indigo,
                title: L10n.settingsTranscriptionPacksTitle,
                help: L10n.settingsTranscriptionPacksHelp
            ) {
                VocabularyPacksField(settings: settings)
            }
        }
    }
}
