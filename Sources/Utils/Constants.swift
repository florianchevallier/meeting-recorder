import Foundation
import CoreGraphics
import AVFoundation

// MARK: - Application Constants

/// Centralized constants to avoid magic numbers throughout the codebase
enum Constants {

    // MARK: - UI Constants

    enum UI {
        // Status Bar Menu
        static let menuWidth: CGFloat = 280
        static let menuHeight: CGFloat = 360
        static let menuIconSize: CGFloat = 20
        static let menuHeaderPadding: CGFloat = 20

        // Status Bar Window
        static let windowInitialWidth: CGFloat = 600
        static let windowInitialHeight: CGFloat = 500
        static let windowMinWidth: CGFloat = 500
        static let windowMinHeight: CGFloat = 400
        static let windowMaxWidth: CGFloat = 800
        static let windowMaxHeight: CGFloat = 700

        // Control Circle
        static let controlCircleSize: CGFloat = 120
        static let controlButtonSize: CGFloat = 80
        static let progressRingLineWidth: CGFloat = 3

        // Recording Progress
        static let maxRecordingDurationForProgress: TimeInterval = 3600 // 1 hour in seconds

        // Quick Action Buttons
        static let quickActionHeight: CGFloat = 44
    }

    // MARK: - Audio Constants

    enum Audio {
        // Sample Rate
        static let sampleRate: Double = 48000.0

        // Buffer Configuration
        static let bufferSize: AVAudioFrameCount = 1024
        static let preferredIOBufferDuration: TimeInterval = 0.005 // 5ms

        // Channel Configuration
        static let stereoChannelCount: UInt32 = 2
        static let monoChannelCount: UInt32 = 1

        // Audio Quality
        static let aacBitRate: Int = 128000 // 128 kbps
        static let audioQualityHigh: Float = 0.8
    }

    // MARK: - Teams Detection Constants

    enum TeamsDetection {
        // Polling Intervals
        static let checkInterval: TimeInterval = 2.0 // Check every 2 seconds
        static let healthCheckInterval: TimeInterval = 5.0 // Health check every 5 seconds

        // Throttling
        static let logThrottleCount: Int = 30 // Log every 30 checks
        static let logThrottleInterval: TimeInterval = 60.0 // 60 seconds between logs

        // Timeouts
        static let meetingDetectionTimeout: TimeInterval = 10.0
    }

    // MARK: - Transcription Constants

    enum Transcription {
        // Polling Configuration
        static let maxPollingAttempts: Int = 360 // Maximum attempts before timeout
        static let pollingInterval: TimeInterval = 5.0 // Check every 5 seconds
        static let maxPollingDuration: TimeInterval = 1800.0 // 30 minutes max

        // File Size Limits
        static let maxFileSizeMB: Int = 25
        static let maxFileSizeBytes: Int = maxFileSizeMB * 1024 * 1024

        // API Configuration
        static let defaultTimeout: TimeInterval = 30.0
        static let uploadTimeout: TimeInterval = 300.0 // 5 minutes for upload
    }

    // MARK: - Recording Constants

    enum Recording {
        // File Stability
        static let fileStabilityCheckInterval: TimeInterval = 0.5 // Check every 500ms
        static let fileStabilityRequiredChecks: Int = 2 // Must be stable for 2 consecutive checks
        static let fileStabilityMaxWaitTime: TimeInterval = 15.0 // Wait max 15 seconds

        // Recovery Configuration
        static let maxRecoveryAttempts: Int = 3
        static let recoveryDelayBase: TimeInterval = 2.0 // Base delay for exponential backoff
        static let recoveryDelayMax: TimeInterval = 10.0

        // Health Monitoring
        static let healthCheckSampleTimeout: TimeInterval = 10.0 // No samples for 10s = unhealthy
        static let healthCheckMemoryWarningThreshold: Int = 80 // 80% memory usage
    }

    // MARK: - Permission Constants

    enum Permissions {
        // Recheck Intervals
        static let recheckDelay: TimeInterval = 2.0
        static let recheckCount: Int = 5
        static let recheckInterval: TimeInterval = 1.0

        // Accessibility Monitoring
        static let accessibilityMonitorAttempts: Int = 20
        static let accessibilityMonitorInterval: TimeInterval = 1.0
    }

    // MARK: - Network Constants

    enum Network {
        static let defaultTimeout: TimeInterval = 30.0
        static let uploadTimeout: TimeInterval = 300.0
        static let maxRetryAttempts: Int = 3
        static let retryDelay: TimeInterval = 2.0
    }

    // MARK: - File System Constants

    enum FileSystem {
        static let tempFilePrefix = "recording_"
        static let systemAudioPrefix = "system_audio_"
        static let unifiedCapturePrefix = "meeting_unified_"
        static let finalRecordingPrefix = "meeting_"

        static let wavExtension = "wav"
        static let m4aExtension = "m4a"
        static let movExtension = "mov"

        static let permissionTestFilename = "permission_test.tmp"
    }

    // MARK: - Date Formatting

    enum DateFormat {
        static let timestamp = "yyyy-MM-dd_HH-mm-ss"
        static let logTimestamp = "yyyy-MM-dd HH:mm:ss.SSS"
        static let displayDate = "yyyy-MM-dd"
        static let displayTime = "HH:mm:ss"
    }

    // MARK: - Animation Constants

    enum Animation {
        static let shortDuration: TimeInterval = 0.2
        static let mediumDuration: TimeInterval = 0.5
        static let longDuration: TimeInterval = 1.0

        static let springResponse: Double = 0.3
        static let springDampingFraction: Double = 0.7

        static let pulseRepeatForever: Bool = true
    }
}

// MARK: - Computed Constants

extension Constants {
    /// Convert seconds to nanoseconds for Task.sleep()
    static func nanoseconds(from seconds: TimeInterval) -> UInt64 {
        return UInt64(seconds * 1_000_000_000)
    }

    /// Convert milliseconds to nanoseconds for Task.sleep()
    static func nanosecondsFromMilliseconds(_ milliseconds: Int) -> UInt64 {
        return UInt64(milliseconds) * 1_000_000
    }
}
