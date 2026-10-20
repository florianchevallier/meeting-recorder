import os
import Foundation

/// Centralized file system utilities to avoid code duplication and force unwrapping
enum FileSystemUtilities {

    // MARK: - Recordings Directory

    /// The user's Documents directory: where recordings lived before 0.8 (migration source only).
    static func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// `~/Library/Application Support/Meety/Recordings`, created if missing. The name is
    /// fixed (not the bundle id) so debug and release builds share their recordings.
    /// - Throws: FileSystemError.recordingsDirectoryUnavailable if it cannot be created
    static func recordingsDirectory() throws -> URL {
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("Meety/Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            Log.app.error("Recordings directory unavailable: \(error.localizedDescription, privacy: .public)")
            throw FileSystemError.recordingsDirectoryUnavailable
        }
    }

    // MARK: - Temporary Directory Access

    /// Safe access to the temporary directory
    /// - Returns: The temporary directory URL
    static func getTemporaryDirectory() -> URL {
        return FileManager.default.temporaryDirectory
    }

    // MARK: - File Operations

    /// Check if a file exists at the given path
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file exists, false otherwise
    static func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Safely delete a file if it exists
    /// - Parameter url: The file URL to delete
    /// - Returns: True if deletion was successful or file didn't exist, false if deletion failed
    @discardableResult
    static func deleteFile(at url: URL) -> Bool {
        guard fileExists(at: url) else {
            return true  // File doesn't exist, consider it "deleted"
        }

        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            Log.app.warning("Failed to delete file at \(url.path): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Create a unique filename with timestamp (local time)
    /// - Parameters:
    ///   - prefix: The filename prefix (e.g., "recording")
    ///   - extension: The file extension (e.g., "m4a")
    ///   - date: The date to format (injectable for tests, defaults to now)
    ///   - timeZone: The timezone for the timestamp (injectable for tests, defaults to local)
    ///   - title: Optional human title (calendar event), sanitized and appended after the timestamp
    /// - Returns: A filename with format: prefix_YYYY-MM-DD_HH-mm-ss[_title].extension
    static func createTimestampedFilename(
        prefix: String,
        extension: String,
        date: Date = Date(),
        timeZone: TimeZone = .current,
        title: String? = nil
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.DateFormat.timestamp
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        let timestamp = dateFormatter.string(from: date)
        let suffix = title.flatMap(sanitizedFilenameComponent).map { "_" + $0 } ?? ""
        return "\(prefix)_\(timestamp)\(suffix).\(`extension`)"
    }

    /// Makes `title` safe for a filename: drops path separators, characters
    /// Finder / SMB reject and control characters, collapses whitespace,
    /// caps the length. Nil when nothing usable is left.
    static func sanitizedFilenameComponent(_ title: String) -> String? {
        let forbidden = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        let cleaned = title.unicodeScalars
            .map { forbidden.contains($0) ? " " : String($0) }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let trimmed = String(cleaned.prefix(Constants.Calendar.maxFilenameTitleLength))
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - File System Errors

enum FileSystemError: Error, LocalizedError {
    case recordingsDirectoryUnavailable
    case fileNotFound(URL)
    case deletionFailed(URL)
    case creationFailed(URL)

    var errorDescription: String? {
        switch self {
        case .recordingsDirectoryUnavailable:
            return "Unable to create the recordings folder in Application Support."
        case .fileNotFound(let url):
            return "File not found at path: \(url.path)"
        case .deletionFailed(let url):
            return "Failed to delete file at path: \(url.path)"
        case .creationFailed(let url):
            return "Failed to create file at path: \(url.path)"
        }
    }
}
