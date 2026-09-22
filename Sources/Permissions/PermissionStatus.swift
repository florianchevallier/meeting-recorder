import Foundation
import SwiftUI

// MARK: - Permission Kind

/// The runtime permissions Meety depends on (calendar is optional).
enum PermissionKind: CaseIterable, Sendable, Equatable {
    case microphone
    /// TCC "System Audio Recording Only" (Core Audio process taps).
    case systemAudio
    /// Accessibility (Teams window titles).
    case accessibility
    /// Full access to calendar events (agenda, event-named recordings).
    case calendar

    /// Deep link into System Settings › Privacy & Security.
    var settingsURL: URL {
        let anchor: String
        switch self {
        case .microphone: anchor = "Privacy_Microphone"
        case .systemAudio: anchor = "Privacy_AudioCapture"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .calendar: anchor = "Privacy_Calendars"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }
}

// MARK: - Permission Status

enum PermissionStatus: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
    /// System audio only: TCC has no query API, the answer is known after the first tap.
    case unknownUntilFirstUse

    var displayName: String {
        switch self {
        case .notDetermined: return L10n.permissionStatusNotDetermined
        case .granted: return L10n.permissionStatusAuthorized
        case .denied: return L10n.permissionStatusDenied
        case .unknownUntilFirstUse: return L10n.permissionStatusUnknownUntilFirstUse
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined, .unknownUntilFirstUse: return .orange
        }
    }
}

// MARK: - System Audio Outcome

/// What the capture side learned about the "System Audio Recording" permission.
enum SystemAudioOutcome: Sendable, Equatable {
    case granted
    case denied
    case indeterminate
}

// MARK: - Permission Errors

enum PermissionError: Error, LocalizedError, Equatable {
    case microphoneDenied
    case systemAudioDenied
    case accessibilityDenied
    case outputFolderNotWritable(URL)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: return L10n.errorMicrophonePermission
        case .systemAudioDenied: return L10n.errorSystemAudioPermission
        case .accessibilityDenied: return L10n.errorAccessibilityPermission
        case .outputFolderNotWritable: return L10n.errorOutputFolderNotWritable
        }
    }
}
