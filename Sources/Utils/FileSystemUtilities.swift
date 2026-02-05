import Foundation

/// Centralized file system utilities to avoid code duplication and force unwrapping
enum FileSystemUtilities {

    // MARK: - Documents Directory Access

    /// Safe access to the user's Documents directory
    /// - Returns: The Documents directory URL, or nil if unavailable (extremely rare in non-sandboxed environments)
    static func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Safe access to the user's Documents directory with fallback
    /// - Parameter fallback: Fallback URL if Documents directory is unavailable
    /// - Returns: The Documents directory URL, or the fallback URL
    static func getDocumentsDirectory(fallback: URL) -> URL {
        return getDocumentsDirectory() ?? fallback
    }

    /// Safe access to the user's Documents directory with error throwing
    /// - Throws: FileSystemError.documentsDirectoryUnavailable if the directory cannot be accessed
    /// - Returns: The Documents directory URL
    static func getDocumentsDirectoryOrThrow() throws -> URL {
        guard let documentsURL = getDocumentsDirectory() else {
            throw FileSystemError.documentsDirectoryUnavailable
        }
        return documentsURL
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
            return true // File doesn't exist, consider it "deleted"
        }

        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            Logger.shared.warning("Failed to delete file at \(url.path): \(error.localizedDescription)", component: "FILE_SYSTEM")
            return false
        }
    }

    /// Create a unique filename with timestamp
    /// - Parameters:
    ///   - prefix: The filename prefix (e.g., "recording")
    ///   - extension: The file extension (e.g., "m4a")
    /// - Returns: A filename with format: prefix_YYYY-MM-DD_HH-mm-ss.extension
    static func createTimestampedFilename(prefix: String, extension: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.DateFormat.timestamp
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = dateFormatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(`extension`)"
    }
}

// MARK: - File System Errors

enum FileSystemError: Error, LocalizedError {
    case documentsDirectoryUnavailable
    case fileNotFound(URL)
    case deletionFailed(URL)
    case creationFailed(URL)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Unable to access the Documents directory. Please check your system permissions."
        case .fileNotFound(let url):
            return "File not found at path: \(url.path)"
        case .deletionFailed(let url):
            return "Failed to delete file at path: \(url.path)"
        case .creationFailed(let url):
            return "Failed to create file at path: \(url.path)"
        }
    }
}
