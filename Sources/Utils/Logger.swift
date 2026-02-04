import Foundation

final class Logger {
    static let shared = Logger()
    private let logFile: URL
    
    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Use different log files for dev vs prod
        let bundleId = Bundle.main.bundleIdentifier ?? "com.meetingrecorder.unknown"
        let appName = bundleId.contains(".dev") ? "MeetyDev" : "Meety"
        logFile = documentsURL.appendingPathComponent("\(appName)_debug.log")
        
        // Clear previous log on startup
        try? "=== \(appName) Debug Log - \(Date()) ===\n".write(to: logFile, atomically: true, encoding: .utf8)
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        // Print to console (for when running from terminal)
        print(logEntry.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Also write to file for app bundle debugging
        if let data = logEntry.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    
    func getLogFileURL() -> URL {
        return logFile
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}