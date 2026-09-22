import Testing
@testable import MeetingRecorder

@Suite("DefaultsKey")
struct DefaultsKeyTests {
    @Test("Legacy raw values are preserved so existing installs keep their state")
    func legacyRawValues() {
        #expect(DefaultsKey.hasCompletedOnboarding.rawValue == "hasCompletedOnboarding")
        #expect(DefaultsKey.accessibilityPrompted.rawValue == "PermissionManager.accessibilityPrompted")
        #expect(DefaultsKey.transcriptionEnabled.rawValue == "transcriptionEnabled")
        #expect(DefaultsKey.apiBaseURL.rawValue == "apiBaseURL")
        #expect(DefaultsKey.autoRecordingEnabled.rawValue == "autoRecordingEnabled")
    }

    @Test("Raw values are unique")
    func unique() {
        let raws = DefaultsKey.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }
}
