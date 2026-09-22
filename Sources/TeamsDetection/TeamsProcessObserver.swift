import os
import AppKit

/// Tracks the set of running Teams process IDs via NSWorkspace notifications.
@MainActor
final class TeamsProcessObserver {
    private let onChange: @MainActor (Set<pid_t>) -> Void
    private var pids: Set<pid_t> = []
    private var tokens: [any NSObjectProtocol] = []

    init(onChange: @escaping @MainActor (Set<pid_t>) -> Void) {
        self.onChange = onChange
    }

    /// Registers the observers and returns the current snapshot.
    func start() -> Set<pid_t> {
        pids = Set(
            NSWorkspace.shared.runningApplications
                .filter { TeamsApp.isTeams(bundleIdentifier: $0.bundleIdentifier) }
                .map(\.processIdentifier))

        let center = NSWorkspace.shared.notificationCenter
        tokens.append(
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    TeamsApp.isTeams(bundleIdentifier: app.bundleIdentifier)
                else { return }
                let pid = app.processIdentifier
                MainActor.assumeIsolated { self?.update { $0.insert(pid) } }
            })
        tokens.append(
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                let pid = app.processIdentifier
                MainActor.assumeIsolated { self?.update { $0.remove(pid) } }
            })
        return pids
    }

    func stop() {
        tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        tokens.removeAll()
    }

    private func update(_ mutate: (inout Set<pid_t>) -> Void) {
        let before = pids
        mutate(&pids)
        if pids != before { onChange(pids) }
    }
}
