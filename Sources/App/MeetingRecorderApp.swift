import os
import Cocoa

/// Pure AppKit entry point: the app lives in the status bar, no SwiftUI scene.
@main
enum MeetyMain {
    @MainActor private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dependencies: AppDependencies?
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dependencies = AppDependencies()
        self.dependencies = dependencies

        dependencies.statusBarController.setup()
        dependencies.permissionMonitor.start()
        dependencies.calendar.start()
        dependencies.transcription.resumePending(in: CalendarMonitor.recordingsInDocuments())
        dependencies.reminderScheduler.start()
        dependencies.coordinator.startTeamsMonitoring()
        dependencies.onboardingCoordinator.presentIfNeeded()
    }

    /// Termination handshake: if a recording is in flight, hold termination,
    /// finalize the M4A, then let the app quit. The watchdog
    /// (`Constants.App.terminationWatchdog`, sized above the engine's own
    /// finalization timeout) guarantees the app always exits.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateLater }

        guard let coordinator = dependencies?.coordinator, coordinator.hasActiveSession else {
            dependencies?.coordinator.stopTeamsMonitoring()
            return .terminateNow
        }

        isTerminating = true
        Log.app.info("Termination requested while recording — finalizing first")

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await coordinator.shutdown() }
                group.addTask {
                    try? await Task.sleep(for: .seconds(Constants.App.terminationWatchdog))
                    Log.app.warning("Shutdown watchdog fired — quitting anyway")
                }
                await group.next()  // first completion wins
                group.cancelAll()
            }

            coordinator.stopTeamsMonitoring()
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.permissionMonitor.stop()
        dependencies?.reminderScheduler.stop()
        dependencies?.calendar.stop()
        dependencies?.statusBarController.tearDown()
    }
}
