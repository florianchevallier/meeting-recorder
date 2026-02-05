import Foundation
import os.log

// MARK: - Logger

/// Unified logging system using Apple's os_log framework
/// - Debug logs: Only visible during development, automatically filtered in production
/// - Info logs: General information, persisted in system logs
/// - Warning logs: Potential issues, persisted in system logs
/// - Error logs: Errors requiring attention, persisted in system logs
///
/// Logs are accessible via Console.app (search for "Meety" or subsystem "com.meetingrecorder.app")
final class Logger {
    static let shared = Logger()

    private let osLog: os.Logger
    private var throttleCache: [String: Date] = [:]
    private let throttleLock = NSLock()

    // MARK: - Initialization

    private init() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.meetingrecorder.app"

        // Create os_log Logger with subsystem and category
        // Subsystem: Reverse DNS identifier (standard Apple convention)
        // Category: General for main logger (components can create specific categories if needed)
        osLog = os.Logger(subsystem: bundleId, category: "general")

        // Log startup info
        osLog.info("🚀 Meety started - Build: \(bundleId)")
    }

    // MARK: - Public Logging Methods

    /// Log a debug message (filtered out in production builds automatically)
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: Optional component name for categorization
    func debug(_ message: String, component: String? = nil) {
        let formattedMessage = formatMessage(message, component: component, emoji: "🔍")
        osLog.debug("\(formattedMessage)")
    }

    /// Log an info message (persisted in system logs)
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: Optional component name for categorization
    func info(_ message: String, component: String? = nil) {
        let formattedMessage = formatMessage(message, component: component, emoji: "ℹ️")
        osLog.info("\(formattedMessage)")
    }

    /// Log a warning message (persisted in system logs)
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: Optional component name for categorization
    func warning(_ message: String, component: String? = nil) {
        let formattedMessage = formatMessage(message, component: component, emoji: "⚠️")
        osLog.warning("\(formattedMessage)")
    }

    /// Log an error message (persisted in system logs)
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: Optional component name for categorization
    func error(_ message: String, component: String? = nil) {
        let formattedMessage = formatMessage(message, component: component, emoji: "❌")
        osLog.error("\(formattedMessage)")
    }

    /// Log a message with throttling to prevent spam
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level (debug, info, warning, error)
    ///   - component: Optional component name
    ///   - throttleInterval: Minimum time between identical messages (default: 30 seconds)
    ///   - throttleKey: Custom key for throttling (default: uses message)
    func logThrottled(
        _ message: String,
        level: LogLevelForThrottling = .info,
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

        // Call appropriate logging method based on level
        switch level {
        case .debug:
            debug(message, component: component)
        case .info:
            info(message, component: component)
        case .warning:
            warning(message, component: component)
        case .error:
            error(message, component: component)
        }
    }

    /// Legacy log method for backward compatibility
    /// - Parameters:
    ///   - message: The message to log
    func log(_ message: String) {
        info(message)
    }

    // MARK: - Private Methods

    private func formatMessage(_ message: String, component: String?, emoji: String) -> String {
        if let component = component {
            return "\(emoji) [\(component)] \(message)"
        } else {
            return "\(emoji) \(message)"
        }
    }

    // MARK: - Utility Methods

    /// Clear the throttle cache (useful for testing or manual reset)
    func clearThrottleCache() {
        throttleLock.lock()
        defer { throttleLock.unlock() }
        throttleCache.removeAll()
    }
}

// MARK: - Log Level for Throttling

/// Log level enum for throttled logging
enum LogLevelForThrottling {
    case debug
    case info
    case warning
    case error
}
