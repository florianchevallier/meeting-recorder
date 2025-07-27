import Foundation

// MARK: - Localization Helper
struct L10n {
    /// Returns a localized string for the given key
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: Bundle.module, comment: "")
        return withVaList(args) { (pointer) in
            NSString(format: format, arguments: pointer) as String
        }
    }
    
}

// MARK: - String Extension for Localization
extension String {
    /// Returns the localized version of this string
    var localized: String {
        return NSLocalizedString(self, bundle: Bundle.module, comment: "")
    }
    
    /// Returns the localized version of this string with arguments
    func localized(_ args: CVarArg...) -> String {
        return L10n.string(self, args)
    }
}

// MARK: - Localized Strings
extension L10n {
    // MARK: - App Info
    static let appName = "app.name".localized
    static let appSubtitle = "app.subtitle".localized
    
    // MARK: - Status
    static let statusReady = "status.ready".localized
    static let statusRecording = "status.recording".localized
    static let statusTeamsDetected = "status.teams_detected".localized
    static let statusTeamsActive = "status.teams_active".localized
    static let statusIdle = "status.idle".localized
    static let statusRecordingShort = "status.recording_short".localized
    static let statusTeamsShort = "status.teams_short".localized
    
    // MARK: - Recording Controls
    static let recordStart = "record.start".localized
    static let recordStop = "record.stop".localized
    static let recordDuration = "record.duration".localized
    
    // MARK: - Quick Actions
    static let actionAutoStart = "action.auto_start".localized
    static let actionAutoStop = "action.auto_stop".localized
    static let actionPermissions = "action.permissions".localized
    static let actionFolder = "action.folder".localized
    static let actionQuit = "action.quit".localized
    
    // MARK: - Teams Detection
    static func teamsAutoStopIn(_ seconds: Int) -> String {
        return "teams.auto_stop_in".localized(seconds)
    }
    static let teamsMeetingActive = "teams.meeting_active".localized
    
    // MARK: - Audio Sources
    static let audioMicrophone = "audio.microphone".localized
    static let audioSystem = "audio.system".localized
    
    // MARK: - Permissions
    static let permissionMicrophoneTitle = "permission.microphone.title".localized
    static let permissionMicrophoneDescription = "permission.microphone.description".localized
    static let permissionScreenRecordingTitle = "permission.screen_recording.title".localized
    static let permissionScreenRecordingDescription = "permission.screen_recording.description".localized
    static let permissionDocumentsTitle = "permission.documents.title".localized
    static let permissionDocumentsDescription = "permission.documents.description".localized
    static let permissionAccessibilityTitle = "permission.accessibility.title".localized
    static let permissionAccessibilityDescription = "permission.accessibility.description".localized
    
    // MARK: - Permission Status
    static let permissionStatusNotDetermined = "permission.status.not_determined".localized
    static let permissionStatusAuthorized = "permission.status.authorized".localized
    static let permissionStatusDenied = "permission.status.denied".localized
    static let permissionStatusRestricted = "permission.status.restricted".localized
    
    // MARK: - Error Messages
    static let errorMicrophonePermission = "error.microphone_permission".localized
    static let errorScreenRecordingPermission = "error.screen_recording_permission".localized
    static let errorDocumentsPermission = "error.documents_permission".localized
    static let errorAccessibilityPermission = "error.accessibility_permission".localized
    
    static func errorRecordingFailed(_ error: String) -> String {
        return "error.recording_failed".localized(error)
    }
    
    static func errorAudioMixingFailed(_ error: String) -> String {
        return "error.audio_mixing_failed".localized(error)
    }
    
    // MARK: - Onboarding
    static let onboardingTitle = "onboarding.title".localized
    static let onboardingWelcome = "onboarding.welcome".localized
    static let onboardingDescription = "onboarding.description".localized
    static let onboardingButtonStart = "onboarding.button.start".localized
    static let onboardingButtonRequestAll = "onboarding.button.request_all".localized
    static let onboardingButtonSkip = "onboarding.button.skip".localized
    static let onboardingButtonOpenPreferences = "onboarding.button.open_preferences".localized
    static let onboardingButtonAuthorize = "onboarding.button.authorize".localized
    
    // MARK: - Log Messages
    static let logRecordingStart = "log.recording_start".localized
    static let logRecordingStop = "log.recording_stop".localized
    static let logTeamsDetected = "log.teams_detected".localized
    static let logTeamsEnded = "log.teams_ended".localized
    static let logAutoRecordingEnabled = "log.auto_recording_enabled".localized
    static let logAutoRecordingDisabled = "log.auto_recording_disabled".localized
    static let logAutoStopEnabled = "log.auto_stop_enabled".localized
    static let logAutoStopDisabled = "log.auto_stop_disabled".localized
}