import Foundation
import CoreAudio

/// Every way the capture pipeline can fail. Pure value, safe to cross actors.
enum CaptureFailure: Error, Sendable, Equatable {
    /// A Core Audio call returned a non-zero status.
    case coreAudio(status: OSStatus, operation: String)
    /// The process tap could not be created (API unavailable / refused).
    case tapUnavailable
    /// No default output device (the tap needs one as clock master).
    case noOutputDevice
    /// No default input device while a microphone was requested.
    case noInputDevice
    /// AVAssetWriter failed; carries the underlying description.
    case writer(String)
    case diskFull
    case documentsUnavailable
    case alreadyRecording
    case notRecording
    /// The IO callback stopped firing.
    case stalled
    /// The "System Audio Recording Only" permission was refused.
    case systemAudioAccessDenied
    /// Finalization exceeded `Constants.Recording.finalizationTimeout`.
    case finalizationTimedOut
}

extension CaptureFailure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .coreAudio(let status, let operation):
            return L10n.errorCaptureCoreAudio(status.fourCharCode, operation)
        case .tapUnavailable: return L10n.errorCaptureTapUnavailable
        case .noOutputDevice: return L10n.errorCaptureNoOutputDevice
        case .noInputDevice: return L10n.errorCaptureNoInputDevice
        case .writer(let detail): return L10n.errorCaptureWriter(detail)
        case .diskFull: return L10n.errorCaptureDiskFull
        case .documentsUnavailable: return L10n.errorCaptureDocumentsUnavailable
        case .alreadyRecording: return L10n.errorCaptureAlreadyRecording
        case .notRecording: return L10n.errorCaptureNotRecording
        case .stalled: return L10n.errorCaptureStalled
        case .systemAudioAccessDenied: return L10n.errorSystemAudioPermission
        case .finalizationTimedOut: return L10n.errorCaptureFinalizationTimeout
        }
    }
}

extension OSStatus {
    /// Renders a Core Audio status as its FourCC when printable (e.g. `'!dev'`),
    /// otherwise as a decimal number.
    var fourCharCode: String {
        let value = UInt32(bitPattern: self)
        let bytes = [
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF),
        ]
        if bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) {
            return "'" + String(decoding: bytes, as: UTF8.self) + "'"
        }
        return String(self)
    }
}
