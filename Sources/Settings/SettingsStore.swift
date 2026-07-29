import Foundation

/// Application settings backed by UserDefaults.
///
/// Replaces `SettingsManager` (ObservableObject/@Published) with `@Observable`.
/// The `UserDefaults` suite is injectable for tests.
@MainActor
@Observable
final class SettingsStore {

    // MARK: - Settings Keys

    private enum Keys {
        static let transcriptionEnabled = "transcriptionEnabled"
        static let apiBaseURL = "apiBaseURL"
        static let whisperModel = "whisperModel"
        static let language = "language"
        static let nbSpeaker = "nbSpeaker"
        static let computeType = "computeType"
        static let autoRecordingEnabled = "autoRecordingEnabled"
    }

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
            defaults.set(transcriptionEnabled, forKey: Keys.transcriptionEnabled)
            Logger.shared.info("Transcription enabled: \(transcriptionEnabled)", component: "SETTINGS")
        }
    }

    var apiBaseURL: String {
        didSet {
            defaults.set(apiBaseURL, forKey: Keys.apiBaseURL)
            Logger.shared.info("API URL updated: \(apiBaseURL)", component: "SETTINGS")
        }
    }

    var whisperModel: String {
        didSet {
            defaults.set(whisperModel, forKey: Keys.whisperModel)
            Logger.shared.info("Whisper model: \(whisperModel)", component: "SETTINGS")
        }
    }

    var language: String {
        didSet {
            defaults.set(language, forKey: Keys.language)
            Logger.shared.info("Language: \(language)", component: "SETTINGS")
        }
    }

    var nbSpeaker: Int {
        didSet {
            defaults.set(nbSpeaker, forKey: Keys.nbSpeaker)
            Logger.shared.info("Number of speakers: \(nbSpeaker)", component: "SETTINGS")
        }
    }

    var computeType: String {
        didSet {
            defaults.set(computeType, forKey: Keys.computeType)
            Logger.shared.info("Compute type: \(computeType)", component: "SETTINGS")
        }
    }

    /// Whether Teams meeting detection should auto-start recording.
    /// Now persisted (was in-memory only in the old StatusBarManager).
    var autoRecordingEnabled: Bool {
        didSet {
            defaults.set(autoRecordingEnabled, forKey: Keys.autoRecordingEnabled)
            Logger.shared.info("Auto recording: \(autoRecordingEnabled)", component: "SETTINGS")
        }
    }

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.transcriptionEnabled = defaults.object(forKey: Keys.transcriptionEnabled) as? Bool
            ?? Defaults.transcriptionEnabled
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL)
            ?? Defaults.apiBaseURL
        self.whisperModel = defaults.string(forKey: Keys.whisperModel)
            ?? Defaults.whisperModel
        self.language = defaults.string(forKey: Keys.language)
            ?? Defaults.language

        let nbSpeakerValue = defaults.integer(forKey: Keys.nbSpeaker)
        self.nbSpeaker = nbSpeakerValue == 0 ? Defaults.nbSpeaker : nbSpeakerValue

        self.computeType = defaults.string(forKey: Keys.computeType)
            ?? Defaults.computeType
        self.autoRecordingEnabled = defaults.object(forKey: Keys.autoRecordingEnabled) as? Bool
            ?? Defaults.autoRecordingEnabled

        Logger.shared.info("Settings loaded (transcription: \(transcriptionEnabled))", component: "SETTINGS")
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
        Logger.shared.info("Reset to defaults", component: "SETTINGS")
    }

    /// Validate API URL format (http/https scheme required)
    func isValidAPIURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }
}
