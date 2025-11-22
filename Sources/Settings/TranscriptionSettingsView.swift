//
//  TranscriptionSettingsView.swift
//  MeetingRecorder
//
//  Settings window for Whisper transcription configuration
//

import SwiftUI

struct TranscriptionSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Configuration Transcription")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Paramètres de l'API Whisper")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.bottom, 10)

            Divider()

            // API URL
            VStack(alignment: .leading, spacing: 8) {
                Label("URL de l'API", systemImage: "link")
                    .font(.system(size: 13, weight: .medium))

                TextField("https://your-api.com/api", text: $settings.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                Text("URL de votre serveur Whisper (avec /api)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Whisper Model
            VStack(alignment: .leading, spacing: 8) {
                Label("Modèle Whisper", systemImage: "cpu")
                    .font(.system(size: 13, weight: .medium))

                Picker("", selection: $settings.whisperModel) {
                    Text("tiny").tag("tiny")
                    Text("base").tag("base")
                    Text("small").tag("small")
                    Text("medium").tag("medium")
                    Text("large-v1").tag("large-v1")
                    Text("large-v2").tag("large-v2")
                    Text("large-v3 (recommandé)").tag("large-v3")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Modèle de reconnaissance vocale (plus grand = plus précis)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Language
            VStack(alignment: .leading, spacing: 8) {
                Label("Langue", systemImage: "globe")
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    Picker("", selection: $settings.language) {
                        Text("Français").tag("fr")
                        Text("English").tag("en")
                        Text("Español").tag("es")
                        Text("Deutsch").tag("de")
                        Text("Italiano").tag("it")
                        Text("Português").tag("pt")
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Text("Code: \(settings.language)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text("Langue de transcription (auto-détection si vide)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Number of speakers
            VStack(alignment: .leading, spacing: 8) {
                Label("Nombre de locuteurs", systemImage: "person.2.fill")
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    Stepper(value: $settings.nbSpeaker, in: 1...20) {
                        Text("\(settings.nbSpeaker) locuteur\(settings.nbSpeaker > 1 ? "s" : "")")
                            .font(.system(size: 12))
                    }
                }

                Text("Estimation pour améliorer la diarisation (séparation des voix)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Compute Type
            VStack(alignment: .leading, spacing: 8) {
                Label("Type de calcul", systemImage: "speedometer")
                    .font(.system(size: 13, weight: .medium))

                Picker("", selection: $settings.computeType) {
                    Text("int8 (M1/M2/M3 - recommandé)").tag("int8")
                    Text("float16 (GPU NVIDIA)").tag("float16")
                    Text("float32 (CPU universel)").tag("float32")
                }
                .pickerStyle(.radioGroup)

                Text("Optimisation selon votre matériel")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Réinitialiser") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Fermer") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

// #Preview {
//     TranscriptionSettingsView()
// }
