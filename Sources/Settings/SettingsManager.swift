//
//  SettingsManager.swift
//  MeetingRecorder
//
//  Manages application settings and preferences
//

import Foundation

/// Manages application settings with UserDefaults persistence
@MainActor
final class SettingsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - Settings Keys

    private enum Keys {
        static let transcriptionEnabled = "transcriptionEnabled"
        static let apiBaseURL = "apiBaseURL"
        static let whisperModel = "whisperModel"
        static let language = "language"
        static let nbSpeaker = "nbSpeaker"
        static let computeType = "computeType"
    }

    // MARK: - Published Properties

    @Published var transcriptionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(transcriptionEnabled, forKey: Keys.transcriptionEnabled)
            Logger.shared.log("⚙️ [SETTINGS] Transcription enabled: \(transcriptionEnabled)")
        }
    }

    @Published var apiBaseURL: String {
        didSet {
            UserDefaults.standard.set(apiBaseURL, forKey: Keys.apiBaseURL)
            Logger.shared.log("⚙️ [SETTINGS] API URL updated: \(apiBaseURL)")
        }
    }

    @Published var whisperModel: String {
        didSet {
            UserDefaults.standard.set(whisperModel, forKey: Keys.whisperModel)
            Logger.shared.log("⚙️ [SETTINGS] Whisper model: \(whisperModel)")
        }
    }

    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: Keys.language)
            Logger.shared.log("⚙️ [SETTINGS] Language: \(language)")
        }
    }

    @Published var nbSpeaker: Int {
        didSet {
            UserDefaults.standard.set(nbSpeaker, forKey: Keys.nbSpeaker)
            Logger.shared.log("⚙️ [SETTINGS] Number of speakers: \(nbSpeaker)")
        }
    }

    @Published var computeType: String {
        didSet {
            UserDefaults.standard.set(computeType, forKey: Keys.computeType)
            Logger.shared.log("⚙️ [SETTINGS] Compute type: \(computeType)")
        }
    }

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults
        self.transcriptionEnabled = UserDefaults.standard.bool(forKey: Keys.transcriptionEnabled)

        self.apiBaseURL = UserDefaults.standard.string(forKey: Keys.apiBaseURL)
            ?? ""

        self.whisperModel = UserDefaults.standard.string(forKey: Keys.whisperModel)
            ?? "large-v3"

        self.language = UserDefaults.standard.string(forKey: Keys.language)
            ?? "fr"

        let nbSpeakerValue = UserDefaults.standard.integer(forKey: Keys.nbSpeaker)
        self.nbSpeaker = nbSpeakerValue == 0 ? 2 : nbSpeakerValue // Default value

        self.computeType = UserDefaults.standard.string(forKey: Keys.computeType)
            ?? "float16"

        Logger.shared.log("⚙️ [SETTINGS] Settings loaded")
        Logger.shared.log("⚙️ [SETTINGS] Transcription enabled: \(transcriptionEnabled)")
    }

    // MARK: - Public Methods

    /// Reset all settings to defaults
    func resetToDefaults() {
        transcriptionEnabled = false
        apiBaseURL = ""
        whisperModel = "large-v3"
        language = "fr"
        nbSpeaker = 2
        computeType = "float16"
        Logger.shared.log("⚙️ [SETTINGS] Reset to defaults")
    }

    /// Validate API URL format
    func isValidAPIURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }
}
