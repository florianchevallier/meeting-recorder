import os
import Foundation

/// Application settings backed by UserDefaults.
///
/// Replaces `SettingsManager` (ObservableObject/@Published) with `@Observable`.
/// The `UserDefaults` suite is injectable for tests.
@MainActor
@Observable
final class SettingsStore {

    // MARK: - Defaults

    enum Defaults {
        static let transcriptionEnabled = false
        static let apiBaseURL = ""
        static let whisperModel = "large-v3"
        static let language = "fr"
        static let nbSpeaker = 2
        static let computeType = "float16"
        static let autoRecordingEnabled = true
    }

    // MARK: - Properties

    private let defaults: UserDefaults

    var transcriptionEnabled: Bool {
        didSet {
            defaults.set(transcriptionEnabled, for: .transcriptionEnabled)
            Log.settings.debug("Transcription enabled: \(self.transcriptionEnabled)")
        }
    }

    var apiBaseURL: String {
        didSet {
            defaults.set(apiBaseURL, for: .apiBaseURL)
        }
    }

    var whisperModel: String {
        didSet {
            defaults.set(whisperModel, for: .whisperModel)
            Log.settings.debug("Whisper model: \(self.whisperModel)")
        }
    }

    var language: String {
        didSet {
            defaults.set(language, for: .language)
            Log.settings.debug("Language: \(self.language)")
        }
    }

    var nbSpeaker: Int {
        didSet {
            defaults.set(nbSpeaker, for: .nbSpeaker)
            Log.settings.debug("Number of speakers: \(self.nbSpeaker)")
        }
    }

    var computeType: String {
        didSet {
            defaults.set(computeType, for: .computeType)
            Log.settings.debug("Compute type: \(self.computeType)")
        }
    }

    /// Whether Teams meeting detection should auto-start recording.
    /// Now persisted (was in-memory only in the old StatusBarManager).
    var autoRecordingEnabled: Bool {
        didSet {
            defaults.set(autoRecordingEnabled, for: .autoRecordingEnabled)
            Log.settings.debug("Auto recording: \(self.autoRecordingEnabled)")
        }
    }

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.transcriptionEnabled =
            defaults.object(for: .transcriptionEnabled) as? Bool
            ?? Defaults.transcriptionEnabled
        self.apiBaseURL =
            defaults.string(for: .apiBaseURL)
            ?? Defaults.apiBaseURL
        self.whisperModel =
            defaults.string(for: .whisperModel)
            ?? Defaults.whisperModel
        self.language =
            defaults.string(for: .language)
            ?? Defaults.language

        let nbSpeakerValue = defaults.integer(for: .nbSpeaker)
        self.nbSpeaker = nbSpeakerValue == 0 ? Defaults.nbSpeaker : nbSpeakerValue

        self.computeType =
            defaults.string(for: .computeType)
            ?? Defaults.computeType
        self.autoRecordingEnabled =
            defaults.object(for: .autoRecordingEnabled) as? Bool
            ?? Defaults.autoRecordingEnabled

        Log.settings.info("Settings loaded (transcription: \(self.transcriptionEnabled))")
    }

    // MARK: - Public Methods

    /// Reset all settings to defaults
    func resetToDefaults() {
        transcriptionEnabled = Defaults.transcriptionEnabled
        apiBaseURL = Defaults.apiBaseURL
        whisperModel = Defaults.whisperModel
        language = Defaults.language
        nbSpeaker = Defaults.nbSpeaker
        computeType = Defaults.computeType
        autoRecordingEnabled = Defaults.autoRecordingEnabled
        Log.settings.info("Reset to defaults")
    }

    /// Validate API URL format (http/https scheme required)
    static func isValidAPIURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }
}
