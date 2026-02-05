import Foundation

// MARK: - Log Level

/// Defines the severity level of log messages
enum LogLevel: Int, Comparable, CustomStringConvertible {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Logger

final class Logger {
    static let shared = Logger()

    private let logFile: URL
    private let logQueue = DispatchQueue(label: "com.meetingrecorder.logger", qos: .utility)
    private var throttleCache: [String: Date] = [:]
    private let throttleLock = NSLock()

    // MARK: - Configuration

    /// Minimum log level to record (default: .debug)
    /// Set to .info for production to reduce noise
    var minimumLogLevel: LogLevel = .debug

    /// Enable/disable console output (default: true)
    var consoleOutputEnabled: Bool = true

    /// Enable/disable file output (default: true)
    var fileOutputEnabled: Bool = true

    // MARK: - Initialization

    private init() {
        // Use different log files for dev vs prod
        let bundleId = Bundle.main.bundleIdentifier ?? "com.meetingrecorder.unknown"
        let appName = bundleId.contains(".dev") ? "MeetyDev" : "Meety"

        // Safe access to Documents directory with fallback to temporary directory
        let documentsURL = FileSystemUtilities.getDocumentsDirectory(
            fallback: FileSystemUtilities.getTemporaryDirectory()
        )

        logFile = documentsURL.appendingPathComponent("\(appName)_debug.log")

        // Clear previous log on startup
        let header = """
        ================================================================================
        \(appName) Debug Log
        Started: \(DateFormatter.logFormatter.string(from: Date()))
        Build: \(bundleId)
        ================================================================================

        """
        try? header.write(to: logFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Public Logging Methods

    /// Log a message with specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level (default: .info)
    ///   - component: Optional component name for categorization
    func log(_ message: String, level: LogLevel = .info, component: String? = nil) {
        guard level >= minimumLogLevel else { return }

        logQueue.async { [weak self] in
            self?.writeLog(message: message, level: level, component: component)
        }
    }

    /// Log a debug message (only in debug builds or when minimumLogLevel <= .debug)
    func debug(_ message: String, component: String? = nil) {
        log(message, level: .debug, component: component)
    }

    /// Log an info message
    func info(_ message: String, component: String? = nil) {
        log(message, level: .info, component: component)
    }

    /// Log a warning message
    func warning(_ message: String, component: String? = nil) {
        log(message, level: .warning, component: component)
    }

    /// Log an error message
    func error(_ message: String, component: String? = nil) {
        log(message, level: .error, component: component)
    }

    /// Log a message with throttling to prevent spam
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level
    ///   - component: Optional component name
    ///   - throttleInterval: Minimum time between identical messages (default: 30 seconds)
    ///   - throttleKey: Custom key for throttling (default: uses message)
    func logThrottled(
        _ message: String,
        level: LogLevel = .info,
        component: String? = nil,
        throttleInterval: TimeInterval = 30.0,
        throttleKey: String? = nil
    ) {
        let key = throttleKey ?? message
        let now = Date()

        throttleLock.lock()
        defer { throttleLock.unlock() }

        if let lastLogTime = throttleCache[key] {
            let timeSinceLastLog = now.timeIntervalSince(lastLogTime)
            if timeSinceLastLog < throttleInterval {
                return // Skip this log (throttled)
            }
        }

        throttleCache[key] = now
        log(message, level: level, component: component)
    }

    // MARK: - Private Methods

    private func writeLog(message: String, level: LogLevel, component: String?) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let componentPrefix = component.map { "[\($0)] " } ?? ""
        let logEntry = "[\(timestamp)] \(level.emoji) [\(level.description)] \(componentPrefix)\(message)\n"

        // Console output
        if consoleOutputEnabled {
            print(logEntry.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // File output
        if fileOutputEnabled {
            writeToFile(logEntry)
        }
    }

    private func writeToFile(_ entry: String) {
        guard let data = entry.data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try? data.write(to: logFile)
        }
    }

    // MARK: - Utility Methods

    func getLogFileURL() -> URL {
        return logFile
    }

    /// Clear the throttle cache (useful for testing or manual reset)
    func clearThrottleCache() {
        throttleLock.lock()
        defer { throttleLock.unlock() }
        throttleCache.removeAll()
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
