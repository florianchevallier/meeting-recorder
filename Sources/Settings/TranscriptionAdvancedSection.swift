import SwiftUI

/// Model, speaker count and compute type: the options most people never touch.
struct TranscriptionAdvancedSection: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
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

            Button(L10n.settingsTranscriptionReset) {
                settings.resetTranscriptionOptions()
            }
            .buttonStyle(.bordered)
        }
    }
}
