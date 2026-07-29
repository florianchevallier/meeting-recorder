import Foundation
import ScreenCaptureKit
import AVFoundation

/// Errors thrown by `CaptureEngine.start()`.
enum CaptureError: Error, LocalizedError {
    case alreadyRecording
    case noDisplay
    case documentsUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "A recording is already in progress."
        case .noDisplay:
            return "No display available for capture."
        case .documentsUnavailable:
            return "Documents directory unavailable."
        }
    }
}

/// Factories for the ScreenCaptureKit objects, kept pure for testability.
enum CaptureConfiguration {

    /// Stream configuration: real display dimensions, 15 fps, cursor visible,
    /// system audio (excluding our own process) and default microphone.
    static func makeStreamConfiguration(display: SCDisplay) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.showsCursor = true

        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true

        configuration.captureMicrophone = true
        if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
            configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
            Logger.shared.debug("Using microphone: \(defaultMicrophone.localizedName)", component: "CAPTURE")
        }
        return configuration
    }

    /// Content filter for macOS 15: `including: applications, exceptingWindows: []`.
    /// ⚠️ Do NOT "simplify" to `init(display:excludingWindows:)` — that was the old bug.
    static func makeContentFilter(display: SCDisplay, applications: [SCRunningApplication]) -> SCContentFilter {
        SCContentFilter(display: display, including: applications, exceptingWindows: [])
    }

    /// Recording output configuration: HEVC .mov in Documents.
    static func makeRecordingConfiguration(outputURL: URL) -> SCRecordingOutputConfiguration {
        let configuration = SCRecordingOutputConfiguration()
        configuration.outputURL = outputURL
        configuration.outputFileType = .mov
        configuration.videoCodecType = .hevc
        return configuration
    }

    /// Timestamped MOV URL in the user's Documents directory (local time).
    static func makeOutputURL() throws -> URL {
        guard let documentsPath = FileSystemUtilities.getDocumentsDirectory() else {
            throw CaptureError.documentsUnavailable
        }
        let filename = FileSystemUtilities.createTimestampedFilename(prefix: "meeting_unified", extension: "mov")
        Logger.shared.info("Recording to: \(filename)", component: "CAPTURE")
        return documentsPath.appendingPathComponent(filename)
    }
}
