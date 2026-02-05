// Logger Migration Guide
// ======================
//
// This file documents how to migrate from the old Logger.shared.log() pattern
// to the new level-based logging system with throttling.
//
// OLD PATTERN:
// ------------
// Logger.shared.log("🎬 [RECORDING] User requested recording start")
// Logger.shared.log("❌ [AUDIO] Failed to create audio file: \(error)")
// Logger.shared.log("🔍 [TEAMS] Teams not running")
//
// NEW PATTERN:
// ------------
// Logger.shared.info("User requested recording start", component: "RECORDING")
// Logger.shared.error("Failed to create audio file: \(error)", component: "AUDIO")
// Logger.shared.debug("Teams not running", component: "TEAMS")
//
// MIGRATION RULES:
// ----------------
//
// 1. Emoji Mapping to Log Levels:
//    🎬 ✅ → .info (general information, successful operations)
//    🔍 📊 🎯 → .debug (detailed debugging, frequent checks)
//    ⚠️ 🩺 → .warning (potential issues, degraded performance)
//    ❌ 💥 → .error (failures, critical problems)
//
// 2. Extract Component Name:
//    [RECORDING] → component: "RECORDING"
//    [AUDIO_MIXER] → component: "AUDIO_MIXER"
//    [TEAMS] → component: "TEAMS"
//
// 3. High-Frequency Logs (use logThrottled):
//    - Audio buffer processing (every frame)
//    - Teams detection checks (every 2 seconds)
//    - Health monitoring (every 5 seconds)
//    - Any log that fires >10 times per minute
//
//    Example:
//    Logger.shared.logThrottled(
//        "Teams not running",
//        level: .debug,
//        component: "TEAMS",
//        throttleInterval: 30.0,  // Only log once every 30 seconds
//        throttleKey: "teams_not_running"
//    )
//
// 4. Configure for Production:
//    In AppDelegate or main initialization:
//    #if DEBUG
//    Logger.shared.minimumLogLevel = .debug
//    #else
//    Logger.shared.minimumLogLevel = .info  // Suppress debug logs in production
//    #endif
//
// EXAMPLES:
// ---------
//
// Recording Start (Info):
// OLD: Logger.shared.log("🎬 [RECORDING] User requested recording start")
// NEW: Logger.shared.info("User requested recording start", component: "RECORDING")
//
// Error Handling (Error):
// OLD: Logger.shared.log("❌ [AUDIO] Failed to create audio file: \(error)")
// NEW: Logger.shared.error("Failed to create audio file: \(error)", component: "AUDIO")
//
// Debug Info (Debug):
// OLD: Logger.shared.log("🔍 [TEAMS] Detection results - Logs: START, Windows: ✅")
// NEW: Logger.shared.debug("Detection results - Logs: START, Windows: ✅", component: "TEAMS")
//
// High-Frequency Throttled (Debug with Throttle):
// OLD: if notRunningLogCounter >= 30 { Logger.shared.log("🔍 [TEAMS] Teams not running"); notRunningLogCounter = 0 }
// NEW: Logger.shared.logThrottled("Teams not running", level: .debug, component: "TEAMS", throttleInterval: 60.0)
//
// Warning (Warning):
// OLD: Logger.shared.log("⚠️ [HEALTH_MONITOR] No samples for \(timeSinceLastSample)s")
// NEW: Logger.shared.warning("No samples for \(timeSinceLastSample)s", component: "HEALTH_MONITOR")

// This file is for documentation only and should not be compiled
#if false

// Example migration for common patterns:

class ExampleMigration {
    func oldPattern() {
        // OLD: Manual throttling with counters
        var logCounter = 0
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            logCounter += 1
            if logCounter >= 30 {
                Logger.shared.log("🔍 [TEAMS] Periodic check")
                logCounter = 0
            }
        }
    }

    func newPattern() {
        // NEW: Built-in throttling
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Logger.shared.logThrottled(
                "Periodic check",
                level: .debug,
                component: "TEAMS",
                throttleInterval: 60.0,
                throttleKey: "teams_periodic_check"
            )
        }
    }
}

#endif
