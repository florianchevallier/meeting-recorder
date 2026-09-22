import Foundation

extension Bundle {
    /// The SwiftPM resource bundle, located the way a shipped app needs.
    ///
    /// The accessor SwiftPM generates for an executable target (`Bundle.module`)
    /// only looks at the root of the main bundle and at the absolute build
    /// directory of the machine that compiled the binary. Neither exists once
    /// the app is assembled by CI and installed elsewhere, so a release build
    /// would trap on first use. Look in `Contents/Resources` first (where
    /// `debug_app.sh` and the release workflow copy the bundle), then fall back
    /// to `Bundle.module` for `swift test`.
    nonisolated static let resources: Bundle = {
        let name = "MeetingRecorder_MeetingRecorder.bundle"
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name),
            let bundle = Bundle(url: url)
        {
            return bundle
        }
        return Bundle.module
    }()
}

// MARK: - Localization Helper
struct L10n {
    /// Returns a localized string for the given key
    static func string(_ key: String, _ args: any CVarArg...) -> String {
        string(key, arguments: args)
    }

    /// Array form — the variadic overload above forwards here, and so must
    /// `String.localized(_:)` (passing a `[CVarArg]` to the variadic version
    /// would wrap the whole array as a single argument).
    static func string(_ key: String, arguments: [any CVarArg]) -> String {
        let format = NSLocalizedString(key, bundle: Bundle.resources, comment: "")
        return withVaList(arguments) { pointer in
            NSString(format: format, arguments: pointer) as String
        }
    }

}

// MARK: - String Extension for Localization
extension String {
    /// Returns the localized version of this string
    var localized: String {
        return NSLocalizedString(self, bundle: Bundle.resources, comment: "")
    }

    /// Returns the localized version of this string with arguments
    func localized(_ args: any CVarArg...) -> String {
        return L10n.string(self, arguments: args)
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
    static let statusFinishing = "status.finishing".localized
    static let statusRecordingShort = "status.recording_short".localized
    static let statusTeamsShort = "status.teams_short".localized
    static let statusFinishingShort = "status.finishing_short".localized
    static let statusStarting = "status.starting".localized
    static let statusReconnecting = "status.reconnecting".localized
    static let statusWaitingSystemAudio = "status.waiting_system_audio".localized

    // MARK: - Recording Controls
    static let recordStart = "record.start".localized
    static let recordStop = "record.stop".localized
    static let recordDuration = "record.duration".localized

    // MARK: - Quick Actions
    static let actionAutoStart = "action.auto_start".localized
    static let actionPermissions = "action.permissions".localized
    static let actionFolder = "action.folder".localized
    static let actionSettings = "action.settings".localized
    static let actionQuit = "action.quit".localized

    // MARK: - Teams Detection
    static let teamsMeetingActive = "teams.meeting_active".localized

    // MARK: - Audio Sources
    static let audioMicrophone = "audio.microphone".localized
    static let audioSystem = "audio.system".localized

    // MARK: - Permissions
    static let permissionMicrophoneTitle = "permission.microphone.title".localized
    static let permissionMicrophoneDescription = "permission.microphone.description".localized
    static let permissionSystemAudioTitle = "permission.system_audio.title".localized
    static let permissionSystemAudioDescription = "permission.system_audio.description".localized
    static let permissionSystemAudioVerify = "permission.system_audio.verify".localized
    static let permissionAccessibilityTitle = "permission.accessibility.title".localized
    static let permissionAccessibilityDescription = "permission.accessibility.description".localized

    // MARK: - Permission Status
    static let permissionStatusNotDetermined = "permission.status.not_determined".localized
    static let permissionStatusAuthorized = "permission.status.authorized".localized
    static let permissionStatusDenied = "permission.status.denied".localized
    static let permissionStatusUnknownUntilFirstUse = "permission.status.unknown_until_first_use".localized

    // MARK: - Error Messages
    static let errorMicrophonePermission = "error.microphone_permission".localized
    static let errorOutputFolderNotWritable = "error.output_folder_not_writable".localized
    static let errorAccessibilityPermission = "error.accessibility_permission".localized

    static func errorRecordingFailed(_ error: String) -> String {
        return "error.recording_failed".localized(error)
    }

    static func errorRecoveryAttempt(_ attempt: Int, _ max: Int) -> String {
        "error.recovery_attempt".localized(attempt, max)
    }

    static func errorCriticalRecording(_ detail: String) -> String {
        "error.critical_recording".localized(detail)
    }

    static let errorSystemAudioPermission = "error.system_audio_permission".localized

    // MARK: - Capture Errors
    static func errorCaptureCoreAudio(_ status: String, _ operation: String) -> String {
        "error.capture.core_audio".localized(status, operation)
    }
    static let errorCaptureTapUnavailable = "error.capture.tap_unavailable".localized
    static let errorCaptureNoOutputDevice = "error.capture.no_output_device".localized
    static let errorCaptureNoInputDevice = "error.capture.no_input_device".localized
    static func errorCaptureWriter(_ detail: String) -> String {
        "error.capture.writer".localized(detail)
    }
    static let errorCaptureDiskFull = "error.capture.disk_full".localized
    static let errorCaptureDocumentsUnavailable = "error.capture.documents_unavailable".localized
    static let errorCaptureAlreadyRecording = "error.capture.already_recording".localized
    static let errorCaptureNotRecording = "error.capture.not_recording".localized
    static let errorCaptureStalled = "error.capture.stalled".localized
    static let errorCaptureFinalizationTimeout = "error.capture.finalization_timeout".localized

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

    // MARK: - Settings Tabs
    static let settingsTabGeneral = "settings.tab.general".localized
    static let settingsTabTranscription = "settings.tab.transcription".localized
    static let settingsTabPermissions = "settings.tab.permissions".localized
    static let settingsWindowTitle = "settings.window.title".localized

    // MARK: - Status Bar Menu
    static let menuTranscriptionRunning = "menu.transcription.running".localized
    static let menuTranscriptionError = "menu.transcription.error".localized
    static let menuErrorOpenPrivacySettings = "menu.error.open_privacy_settings".localized
    static let menuErrorOpenFolder = "menu.error.open_folder".localized

    // MARK: - Transcription Progress
    static let transcriptionProgressPreparing = "transcription.progress.preparing".localized
    static let transcriptionProgressConverting = "transcription.progress.converting".localized
    static let transcriptionProgressUploading = "transcription.progress.uploading".localized
    static let transcriptionProgressStarted = "transcription.progress.started".localized
    static let transcriptionProgressPending = "transcription.progress.pending".localized
    static let transcriptionProgressRunning = "transcription.progress.running".localized
    static let transcriptionProgressCompleted = "transcription.progress.completed".localized
    static let transcriptionProgressFailed = "transcription.progress.failed".localized
    static let transcriptionProgressSaved = "transcription.progress.saved".localized

    // MARK: - Transcription Errors
    static let transcriptionErrorJobFailed = "transcription.error.job_failed".localized
    static let transcriptionErrorTimeoutStatus = "transcription.error.timeout_status".localized
    static let transcriptionErrorTooLong = "transcription.error.too_long".localized
    static let transcriptionErrorNoFile = "transcription.error.no_file".localized
    static func transcriptionErrorSaveFailed(_ message: String) -> String {
        L10n.string("transcription.error.save_failed", message)
    }
    static func transcriptionErrorPrefixed(_ message: String) -> String {
        L10n.string("transcription.error.prefixed", message)
    }

    // MARK: - API Errors
    static let apiErrorInvalidURL = "api.error.invalid_url".localized
    static let apiErrorInvalidResponse = "api.error.invalid_response".localized
    static let apiErrorInvalidData = "api.error.invalid_data".localized
    static let apiErrorJobNotFound = "api.error.job_not_found".localized
    static let apiErrorJobNotCompleted = "api.error.job_not_completed".localized
    static let apiErrorResultNotFound = "api.error.result_not_found".localized
    static let apiErrorMissingBaseURL = "api.error.missing_base_url".localized
    static func apiErrorBadRequest(_ message: String) -> String {
        L10n.string("api.error.bad_request", message)
    }
    static func apiErrorServerError(_ message: String) -> String {
        L10n.string("api.error.server_error", message)
    }
    static func apiErrorUnexpectedStatus(_ code: Int) -> String {
        L10n.string("api.error.unexpected_status", code)
    }

    // MARK: - Settings - General
    static let settingsGeneralHeaderTitle = "settings.general.header.title".localized
    static let settingsGeneralHeaderSubtitle = "settings.general.header.subtitle".localized
    static let settingsGeneralAutoRecordingTitle = "settings.general.auto_recording.title".localized
    static let settingsGeneralAutoRecordingSubtitle = "settings.general.auto_recording.subtitle".localized
    static let settingsGeneralTranscriptionTitle = "settings.general.transcription.title".localized
    static let settingsGeneralTranscriptionSubtitle = "settings.general.transcription.subtitle".localized
    static let settingsGeneralQuitTitle = "settings.general.quit.title".localized
    static let settingsGeneralQuitSubtitle = "settings.general.quit.subtitle".localized

    // MARK: - Settings - Transcription
    static let settingsTranscriptionHeaderTitle = "settings.transcription.header.title".localized
    static let settingsTranscriptionHeaderSubtitle = "settings.transcription.header.subtitle".localized
    static let settingsTranscriptionApiTitle = "settings.transcription.api.title".localized
    static let settingsTranscriptionApiPlaceholder = "settings.transcription.api.placeholder".localized
    static let settingsTranscriptionApiInvalid = "settings.transcription.api.invalid".localized
    static let settingsTranscriptionApiHelp = "settings.transcription.api.help".localized
    static let settingsTranscriptionModelTitle = "settings.transcription.model.title".localized
    static let settingsTranscriptionModelHelp = "settings.transcription.model.help".localized
    static let settingsTranscriptionLanguageTitle = "settings.transcription.language.title".localized
    static let settingsTranscriptionLanguageHelp = "settings.transcription.language.help".localized
    static let settingsTranscriptionLanguageCodeFormat = "settings.transcription.language.code".localized
    static let settingsTranscriptionSpeakersTitle = "settings.transcription.speakers.title".localized
    static let settingsTranscriptionSpeakersHelp = "settings.transcription.speakers.help".localized
    static let settingsTranscriptionSpeakersCountFormat = "settings.transcription.speakers.count".localized
    static let settingsTranscriptionComputeTitle = "settings.transcription.compute.title".localized
    static let settingsTranscriptionComputeHelp = "settings.transcription.compute.help".localized
    static let settingsTranscriptionReset = "settings.transcription.reset".localized

    // MARK: - Settings - Permissions
    static let settingsPermissionsHeaderTitle = "settings.permissions.header.title".localized
    static let settingsPermissionsHeaderSubtitle = "settings.permissions.header.subtitle".localized
}

// MARK: - Calendar
extension L10n {
    static let permissionCalendarTitle = "permission.calendar.title".localized
    static let permissionCalendarDescription = "permission.calendar.description".localized

    static let calendarSectionTitle = "calendar.section.title".localized
    static let calendarPastTitle = "calendar.past.title".localized
    static let calendarConnect = "calendar.connect".localized
    static let calendarEmpty = "calendar.empty".localized
    static let calendarInProgress = "calendar.in_progress".localized
    static let calendarUntitledEvent = "calendar.untitled".localized
    static let calendarJoin = "calendar.join".localized
    static let calendarPlayRecording = "calendar.play_recording".localized
    static let calendarShowInFinder = "calendar.show_in_finder".localized
    static let calendarOpenTranscript = "calendar.open_transcript".localized
    static let calendarReminderRecordAction = "calendar.reminder.record".localized

    static func calendarStartsIn(_ minutes: Int) -> String {
        L10n.string("calendar.starts_in", minutes)
    }
    static func calendarParticipants(_ count: Int) -> String {
        L10n.string("calendar.participants", count)
    }
    static func calendarReminderBody(_ time: String) -> String {
        L10n.string("calendar.reminder.body", time)
    }

    static let settingsTabCalendar = "settings.tab.calendar".localized
    static let settingsCalendarHeaderTitle = "settings.calendar.header.title".localized
    static let settingsCalendarHeaderSubtitle = "settings.calendar.header.subtitle".localized
    static let settingsCalendarEnabledTitle = "settings.calendar.enabled.title".localized
    static let settingsCalendarEnabledSubtitle = "settings.calendar.enabled.subtitle".localized
    static let settingsCalendarRemindersTitle = "settings.calendar.reminders.title".localized
    static let settingsCalendarRemindersSubtitle = "settings.calendar.reminders.subtitle".localized
    static let settingsCalendarLeadTitle = "settings.calendar.lead.title".localized
    static let settingsCalendarPickerTitle = "settings.calendar.picker.title".localized
    static let settingsCalendarPickerHelp = "settings.calendar.picker.help".localized
    static let settingsCalendarPickerOtherAccount = "settings.calendar.picker.other_account".localized
    static func settingsCalendarLeadMinutes(_ minutes: Int) -> String {
        L10n.string("settings.calendar.lead.minutes", minutes)
    }
}
