import Testing
import Foundation
@testable import MeetingRecorder

@Suite("SettingsStore")
@MainActor
struct SettingsStoreTests {

    private func makeStore() -> (SettingsStore, UserDefaults) {
        let suiteName = "meety-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
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
    }

    @Test("Values persist to UserDefaults and survive reload")
    func persistence() {
        let (store, defaults) = makeStore()
        store.whisperModel = "small"
        store.language = "en"
        store.nbSpeaker = 4
        store.autoRecordingEnabled = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.whisperModel == "small")
        #expect(reloaded.language == "en")
        #expect(reloaded.nbSpeaker == 4)
        #expect(reloaded.autoRecordingEnabled == false)
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

    @Test("API URL validation requires http/https scheme", arguments: [
        ("https://api.example.com", true),
        ("http://localhost:8000", true),
        ("ftp://example.com", false),
        ("not a url", false),
        ("", false)
    ])
    func urlValidation(url: String, expected: Bool) {
        let (store, _) = makeStore()
        #expect(store.isValidAPIURL(url) == expected)
    }
}
