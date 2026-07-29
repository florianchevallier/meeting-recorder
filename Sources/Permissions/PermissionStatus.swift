import Foundation
import SwiftUI
import AVFoundation

// MARK: - Permission Status

enum PermissionStatus: String, CaseIterable, Sendable {
    case notDetermined = "not_determined"
    case authorized = "authorized"
    case denied = "denied"
    case restricted = "restricted"

    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }

    var displayName: String {
        switch self {
        case .notDetermined: return L10n.permissionStatusNotDetermined
        case .authorized: return L10n.permissionStatusAuthorized
        case .denied: return L10n.permissionStatusDenied
        case .restricted: return L10n.permissionStatusRestricted
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        }
    }
}

// MARK: - Permission Errors

enum PermissionError: Error, LocalizedError {
    case microphonePermissionDenied
    case screenRecordingPermissionDenied
    case documentsPermissionDenied
    case accessibilityPermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return L10n.errorMicrophonePermission
        case .screenRecordingPermissionDenied:
            return L10n.errorScreenRecordingPermission
        case .documentsPermissionDenied:
            return L10n.errorDocumentsPermission
        case .accessibilityPermissionDenied:
            return L10n.errorAccessibilityPermission
        }
    }
}
