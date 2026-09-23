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
        static let transcriptionGlossary = ""
        static let autoRecordingEnabled = true
        static let calendarEnabled = true
        static let calendarRemindersEnabled = false
        static let calendarReminderLeadMinutes = Constants.Calendar.defaultReminderLeadMinutes
        static let liveTranscriptionEnabled = true
        static let transcriptionOnlyWithMeeting = false
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

    /// Words WhisperX should expect (jargon, product names), added to the prompt.
    var transcriptionGlossary: String {
        didSet {
            defaults.set(transcriptionGlossary, for: .transcriptionGlossary)
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

    /// Calendar integration (popover agenda, event-named files, sidecar metadata).
    var calendarEnabled: Bool {
        didSet {
            defaults.set(calendarEnabled, for: .calendarEnabled)
            Log.settings.debug("Calendar enabled: \(self.calendarEnabled)")
        }
    }

    var calendarRemindersEnabled: Bool {
        didSet {
            defaults.set(calendarRemindersEnabled, for: .calendarRemindersEnabled)
            Log.settings.debug("Calendar reminders: \(self.calendarRemindersEnabled)")
        }
    }

    var calendarReminderLeadMinutes: Int {
        didSet {
            defaults.set(calendarReminderLeadMinutes, for: .calendarReminderLeadMinutes)
            Log.settings.debug("Calendar reminder lead: \(self.calendarReminderLeadMinutes) min")
        }
    }

    /// Calendars feeding Meety; `nil` = all (see `CalendarSelection`).
    var calendarSelectedIDs: Set<String>? {
        didSet {
            defaults.set(calendarSelectedIDs.map { Array($0).sorted() }, for: .calendarSelectedIDs)
            Log.settings.debug("Calendar selection: \(self.calendarSelectedIDs?.count ?? -1) calendars")
        }
    }

    /// On-device transcript shown live while recording (and saved as `<recording>.live.md`).
    var liveTranscriptionEnabled: Bool {
        didSet {
            defaults.set(liveTranscriptionEnabled, for: .liveTranscriptionEnabled)
            Log.settings.debug("Live transcription: \(self.liveTranscriptionEnabled)")
        }
    }

    /// Automatic transcription skips recordings without a calendar event.
    var transcriptionOnlyWithMeeting: Bool {
        didSet {
            defaults.set(transcriptionOnlyWithMeeting, for: .transcriptionOnlyWithMeeting)
            Log.settings.debug("Transcription only with meeting: \(self.transcriptionOnlyWithMeeting)")
        }
    }

    /// Selected `VocabularyPack` raw values.
    var vocabularyPacks: Set<String> {
        didSet {
            defaults.set(Array(vocabularyPacks).sorted(), for: .vocabularyPacks)
        }
    }

    /// Packs made by the user, in creation order.
    var customVocabularyPacks: [CustomVocabularyPack] {
        didSet {
            defaults.set(try? JSONEncoder().encode(customVocabularyPacks), for: .customVocabularyPacks)
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
        self.transcriptionGlossary =
            defaults.string(for: .transcriptionGlossary)
            ?? Defaults.transcriptionGlossary
        self.autoRecordingEnabled =
            defaults.object(for: .autoRecordingEnabled) as? Bool
            ?? Defaults.autoRecordingEnabled
        self.calendarEnabled =
            defaults.object(for: .calendarEnabled) as? Bool
            ?? Defaults.calendarEnabled
        self.calendarRemindersEnabled =
            defaults.object(for: .calendarRemindersEnabled) as? Bool
            ?? Defaults.calendarRemindersEnabled
        self.calendarReminderLeadMinutes =
            defaults.object(for: .calendarReminderLeadMinutes) as? Int
            ?? Defaults.calendarReminderLeadMinutes
        self.calendarSelectedIDs = (defaults.object(for: .calendarSelectedIDs) as? [String]).map(Set.init)
        self.liveTranscriptionEnabled =
            defaults.object(for: .liveTranscriptionEnabled) as? Bool
            ?? Defaults.liveTranscriptionEnabled
        self.transcriptionOnlyWithMeeting =
            defaults.object(for: .transcriptionOnlyWithMeeting) as? Bool
            ?? Defaults.transcriptionOnlyWithMeeting
        self.vocabularyPacks = Set(defaults.object(for: .vocabularyPacks) as? [String] ?? [])
        self.customVocabularyPacks =
            (defaults.object(for: .customVocabularyPacks) as? Data)
            .flatMap { try? JSONDecoder().decode([CustomVocabularyPack].self, from: $0) } ?? []

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
        transcriptionGlossary = Defaults.transcriptionGlossary
        autoRecordingEnabled = Defaults.autoRecordingEnabled
        calendarEnabled = Defaults.calendarEnabled
        calendarRemindersEnabled = Defaults.calendarRemindersEnabled
        calendarReminderLeadMinutes = Defaults.calendarReminderLeadMinutes
        calendarSelectedIDs = nil
        liveTranscriptionEnabled = Defaults.liveTranscriptionEnabled
        transcriptionOnlyWithMeeting = Defaults.transcriptionOnlyWithMeeting
        vocabularyPacks = []
        Log.settings.info("Reset to defaults")
    }

    /// Adds a new pack (selected right away) or replaces the one with the same id.
    func saveCustomPack(_ pack: CustomVocabularyPack) {
        if let index = customVocabularyPacks.firstIndex(where: { $0.id == pack.id }) {
            customVocabularyPacks[index] = pack
        } else {
            customVocabularyPacks.append(pack)
            vocabularyPacks.insert(pack.id)
        }
    }

    func deleteCustomPack(id: String) {
        customVocabularyPacks.removeAll { $0.id == id }
        vocabularyPacks.remove(id)
    }

    /// Resets what the Transcription tab's Reset button covers; the server and the
    /// user's own packs stay (packs are only unchecked).
    func resetTranscriptionOptions() {
        whisperModel = Defaults.whisperModel
        language = Defaults.language
        nbSpeaker = Defaults.nbSpeaker
        computeType = Defaults.computeType
        transcriptionGlossary = Defaults.transcriptionGlossary
        vocabularyPacks = []
        Log.settings.info("Transcription options reset")
    }

    /// Whether a recording that just ended goes to the transcription queue.
    func shouldAutoTranscribe(hasMeeting: Bool) -> Bool {
        transcriptionEnabled && (hasMeeting || !transcriptionOnlyWithMeeting)
    }

    /// Validate API URL format (http/https scheme required)
    static func isValidAPIURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }
}
