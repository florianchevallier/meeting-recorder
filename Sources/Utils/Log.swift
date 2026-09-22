import Foundation
import os

/// Per-component `os.Logger` instances (subsystem = bundle identifier).
///
/// Usage: `Log.capture.info("Started \(url.lastPathComponent, privacy: .public)")`.
/// Interpolated `String`s are private by default in release builds; mark values
/// that must stay readable in Console with `privacy: .public`.
///
/// Filter in Console / `log stream`:
/// `--predicate 'subsystem == "com.meetingrecorder.meety" AND category == "capture"'`
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.meetingrecorder.meety"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let recording = Logger(subsystem: subsystem, category: "recording")
    static let teams = Logger(subsystem: subsystem, category: "teams")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
}
