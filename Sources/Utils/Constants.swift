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
        static let maxRecordingDurationForProgress: TimeInterval = 3600  // 1 hour in seconds

        // Quick Action Buttons
        static let quickActionHeight: CGFloat = 44
    }

    // MARK: - Teams Detection Constants

    enum TeamsDetection {
        /// A signal transition must hold this long before a meeting start/end is emitted
        static let debounce: TimeInterval = 3.0
        /// Slow safety-net rescan of Teams windows while Teams runs (AX notifications are the fast path)
        static let windowFallbackPollInterval: TimeInterval = 15.0
        static let windowFallbackPollTolerance: TimeInterval = 5.0
        /// Coalesce bursts of AX notifications before rescanning
        static let windowRescanCoalesce: TimeInterval = 0.3
        /// Max time an Accessibility request may block (default is 6 s)
        static let axMessagingTimeout: Float = 0.5
        /// The per-process "running input" flag lags the device-level trigger
        static let microphoneRecheckDelay: TimeInterval = 0.5
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
        // Tap restart policy (device change, stall)
        static let maxRecoveryAttempts: Int = 3
        static let recoveryDelay: TimeInterval = 1.0
        /// Coalesce bursts of Core Audio device notifications
        static let deviceChangeDebounce: TimeInterval = 0.5

        // Health monitoring
        static let healthPollInterval: TimeInterval = 2.0
        /// No IO callback for this long = stalled → restart the tap
        static let healthStallTimeout: TimeInterval = 3.0
        /// System tap silent for this long = informational `degraded` event
        static let systemSilenceTimeout: TimeInterval = 30.0
        /// Writer back-pressure: drop IO cycles above this many queued frames (≈5 s at 48 kHz)
        static let maxPendingFrames: Int = 240_000

        // Finalization
        static let finalizationTimeout: TimeInterval = 10.0
        /// Silence inserted to keep wall-clock alignment across a restart is capped here
        static let maxSilenceGapFill: TimeInterval = 10.0
        /// AVAssetWriter fragment interval (keeps a crashed recording playable)
        static let fragmentInterval: TimeInterval = 10.0
    }

    // MARK: - App Lifecycle

    enum App {
        /// Must exceed `Recording.finalizationTimeout` plus a margin
        static let terminationWatchdog: TimeInterval = 15.0
    }

    // MARK: - Permission Constants

    enum Permissions {
        /// Bounded recheck after deep-linking into System Settings (stops early once granted)
        static let recheckCount: Int = 30
        static let recheckInterval: TimeInterval = 1.0

        /// Recording filename prefix / extension
        static let recordingPrefix = "meeting"
        static let recordingExtension = "m4a"
    }

    // MARK: - Date Formatting

    enum DateFormat {
        static let timestamp = "yyyy-MM-dd_HH-mm-ss"
    }
}
