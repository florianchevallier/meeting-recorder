import SwiftUI
import Cocoa

@main
struct MeetingRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Hidden WindowGroup — the app lives entirely in the status bar
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var dependencies: AppDependencies?
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide all windows, status bar only (no Dock icon)
        NSApp.windows.forEach { $0.orderOut(nil) }
        NSApp.setActivationPolicy(.accessory)

        let dependencies = AppDependencies()
        self.dependencies = dependencies

        dependencies.statusBarController.setup()
        dependencies.coordinator.startTeamsMonitoring()
        dependencies.onboardingCoordinator.presentIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Never reopen windows — status bar only
        return false
    }

    /// Termination handshake: if a recording is in flight, hold termination,
    /// finalize the M4A, then let the app quit. A 60s watchdog guarantees the
    /// app always exits (the old fire-and-forget cleanup truncated the MOV).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateLater }

        guard let coordinator = dependencies?.coordinator, coordinator.isRecording else {
            dependencies?.coordinator.stopTeamsMonitoring()
            return .terminateNow
        }

        isTerminating = true
        Logger.shared.info("Termination requested while recording — finalizing first", component: "APP")

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await coordinator.shutdown() }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 60_000_000_000) // watchdog
                    Logger.shared.warning("Shutdown watchdog fired — quitting anyway", component: "APP")
                }
                await group.next() // first completion wins
                group.cancelAll()
            }

            coordinator.stopTeamsMonitoring()
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.statusBarController.tearDown()
    }
}
