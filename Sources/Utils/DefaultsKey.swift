import Foundation

/// Every `UserDefaults` key the app writes, in one place. Raw values of the
/// legacy keys are preserved so existing installs keep their state.
enum DefaultsKey: String, CaseIterable, Sendable {
    // Settings
    case transcriptionEnabled
    case apiBaseURL
    case whisperModel
    case language
    case nbSpeaker
    case computeType
    case autoRecordingEnabled
    case calendarEnabled
    case calendarRemindersEnabled
    case calendarReminderLeadMinutes
    case calendarSelectedIDs

    // Onboarding / permissions
    case hasCompletedOnboarding = "hasCompletedOnboarding"
    case accessibilityPrompted = "PermissionManager.accessibilityPrompted"
    case systemAudioPrompted = "SystemAudio.prompted"
    case systemAudioVerified = "SystemAudio.verified"
}

extension UserDefaults {
    func bool(for key: DefaultsKey) -> Bool { bool(forKey: key.rawValue) }
    func integer(for key: DefaultsKey) -> Int { integer(forKey: key.rawValue) }
    func string(for key: DefaultsKey) -> String? { string(forKey: key.rawValue) }
    func object(for key: DefaultsKey) -> Any? { object(forKey: key.rawValue) }
    func set(_ value: Any?, for key: DefaultsKey) { set(value, forKey: key.rawValue) }
}
