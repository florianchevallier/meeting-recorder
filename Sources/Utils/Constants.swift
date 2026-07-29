import Foundation
import CoreGraphics

// MARK: - Application Constants

/// Centralized constants to avoid magic numbers throughout the codebase.
/// Only sections actually referenced by the code are kept.
enum Constants {

    // MARK: - UI Constants

    enum UI {
        // Status Bar Menu
        static let menuWidth: CGFloat = 280
        static let menuHeight: CGFloat = 360

        // Settings Window
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

    // MARK: - Teams Detection Constants

    enum TeamsDetection {
        /// Check every 2 seconds
        static let checkInterval: TimeInterval = 2.0
        /// Log every 30 checks
        static let logThrottleCount: Int = 30
    }

    // MARK: - Transcription Constants

    enum Transcription {
        /// Maximum polling attempts before timeout (360 × 5s = 30 minutes)
        static let maxPollingAttempts: Int = 360
        /// Interval between job status polls
        static let pollingInterval: TimeInterval = 5.0
        /// Initial delay before first poll
        static let initialPollingDelay: TimeInterval = 2.0

        /// URLSession request timeout
        static let defaultTimeout: TimeInterval = 30.0
        /// URLSession resource timeout (upload of large audio files)
        static let uploadTimeout: TimeInterval = 300.0
    }

    // MARK: - Recording Constants

    enum Recording {
        // File Stability (pre-conversion and finalization watcher)
        static let fileStabilityCheckInterval: TimeInterval = 0.5
        /// Consecutive stable checks required by the MOV→M4A pre-flight
        static let converterStabilityRequiredChecks: Int = 2
        /// Consecutive stable checks required by the finalization fallback watcher
        static let finalizationStabilityRequiredChecks: Int = 3
        /// Max wait for MOV stability before conversion
        static let converterMaxWaitTime: TimeInterval = 15.0
        /// Max wait for the recording-finalization delegate callback
        static let finalizationMaxWaitTime: TimeInterval = 120.0

        // Recovery Configuration
        static let maxRecoveryAttempts: Int = 3
        static let recoveryDelay: TimeInterval = 2.0

        // Health Monitoring
        static let healthCheckInterval: TimeInterval = 5.0
        /// No samples for this long = unhealthy
        static let healthCheckSampleTimeout: TimeInterval = 10.0
    }

    // MARK: - Permission Constants

    enum Permissions {
        /// Recheck loop after opening System Settings
        static let recheckDelay: TimeInterval = 2.0
        static let recheckCount: Int = 5
        static let recheckInterval: TimeInterval = 1.0

        /// Accessibility trust polling after request
        static let accessibilityMonitorAttempts: Int = 20
        static let accessibilityMonitorInterval: TimeInterval = 1.0

        static let permissionTestFilename = "permission_test.tmp"
    }

    // MARK: - Date Formatting

    enum DateFormat {
        static let timestamp = "yyyy-MM-dd_HH-mm-ss"
    }
}
