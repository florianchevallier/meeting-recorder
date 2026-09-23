import Testing
import Foundation
@testable import MeetingRecorder

@Suite("SettingsStore")
@MainActor
struct SettingsStoreTests {

    private func makeStore() -> (SettingsStore, UserDefaults) {
        let defaults = ScratchDefaults.make()
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test("Defaults are correct on fresh install")
    func defaults() {
        let (store, _) = makeStore()
        #expect(store.transcriptionEnabled == false)
        #expect(store.apiBaseURL == "")
        #expect(store.whisperModel == "large-v3")
        #expect(store.language == "fr")
        #expect(store.nbSpeaker == 2)
        #expect(store.computeType == "float16")
        #expect(store.autoRecordingEnabled == true)
        #expect(store.calendarEnabled == true)
        #expect(store.calendarRemindersEnabled == false)
        #expect(store.calendarReminderLeadMinutes == 1)
        #expect(store.calendarSelectedIDs == nil)
        #expect(store.liveTranscriptionEnabled == true)
        #expect(store.transcriptionOnlyWithMeeting == false)
        #expect(store.vocabularyPacks.isEmpty)
    }

    @Test("Vocabulary packs and the meeting-only option persist")
    func transcriptionOptionsPersist() {
        let (store, defaults) = makeStore()
        store.vocabularyPacks = ["agile", "development"]
        store.transcriptionOnlyWithMeeting = true
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.vocabularyPacks == ["agile", "development"])
        #expect(reloaded.transcriptionOnlyWithMeeting)
    }

    @Test(
        "Auto-transcription honours the meeting-only option",
        arguments: [
            (false, false, false, false),
            (false, true, true, false),
            (true, false, false, true),
            (true, false, true, true),
            (true, true, false, false),
            (true, true, true, true),
        ])
    func autoTranscribe(enabled: Bool, onlyWithMeeting: Bool, hasMeeting: Bool, expected: Bool) {
        let (store, _) = makeStore()
        store.transcriptionEnabled = enabled
        store.transcriptionOnlyWithMeeting = onlyWithMeeting
        #expect(store.shouldAutoTranscribe(hasMeeting: hasMeeting) == expected)
    }

    @Test("Custom packs persist, a new one is selected, deleting unselects it")
    func customPacks() {
        let (store, defaults) = makeStore()
        var pack = CustomVocabularyPack(id: "p", name: "Client", terms: ["Meety"])
        store.saveCustomPack(pack)
        #expect(store.vocabularyPacks.contains("p"))

        pack.terms.append("WhisperX")
        store.saveCustomPack(pack)
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.customVocabularyPacks == [pack])

        store.resetTranscriptionOptions()
        #expect(store.customVocabularyPacks == [pack])
        #expect(store.vocabularyPacks.isEmpty)

        store.vocabularyPacks = ["p"]
        store.deleteCustomPack(id: "p")
        #expect(store.customVocabularyPacks.isEmpty)
        #expect(store.vocabularyPacks.isEmpty)
    }

    @Test("Resetting transcription options keeps the server")
    func resetTranscriptionOptions() {
        let (store, _) = makeStore()
        store.apiBaseURL = "https://example.com/api"
        store.whisperModel = "tiny"
        store.vocabularyPacks = ["data"]
        store.transcriptionGlossary = "Meety"
        store.resetTranscriptionOptions()
        #expect(store.apiBaseURL == "https://example.com/api")
        #expect(store.whisperModel == "large-v3")
        #expect(store.vocabularyPacks.isEmpty)
        #expect(store.transcriptionGlossary == "")
    }

    @Test("Calendar selection persists, and nil removes the key")
    func calendarSelection() {
        let (store, defaults) = makeStore()
        store.calendarSelectedIDs = ["work", "team"]
        #expect(SettingsStore(defaults: defaults).calendarSelectedIDs == ["work", "team"])
        store.calendarSelectedIDs = nil
        #expect(SettingsStore(defaults: defaults).calendarSelectedIDs == nil)
    }

    @Test("Values persist to UserDefaults and survive reload")
    func persistence() {
        let (store, defaults) = makeStore()
        store.whisperModel = "small"
        store.language = "en"
        store.nbSpeaker = 4
        store.autoRecordingEnabled = false
        store.liveTranscriptionEnabled = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.whisperModel == "small")
        #expect(reloaded.language == "en")
        #expect(reloaded.nbSpeaker == 4)
        #expect(reloaded.autoRecordingEnabled == false)
        #expect(reloaded.liveTranscriptionEnabled == false)
    }

    @Test("resetToDefaults restores every default")
    func reset() {
        let (store, _) = makeStore()
        store.whisperModel = "tiny"
        store.autoRecordingEnabled = false
        store.resetToDefaults()

        #expect(store.whisperModel == "large-v3")
        #expect(store.autoRecordingEnabled == true)
    }

    @Test(
        "API URL validation requires http/https scheme",
        arguments: [
            ("https://api.example.com", true),
            ("http://localhost:8000", true),
            ("ftp://example.com", false),
            ("not a url", false),
            ("", false),
        ])
    func urlValidation(url: String, expected: Bool) {
        #expect(SettingsStore.isValidAPIURL(url) == expected)
    }
}
