import os
import AppKit
import ApplicationServices

/// "Does Teams have a meeting window?" — AXObserver notifications on each
/// Teams process (main run loop, callbacks only mark the state dirty), a
/// coalesced rescan off the main actor, and a slow fallback poll while Teams
/// runs. Nothing runs when Teams is not running or Accessibility is not granted.
@MainActor
final class TeamsWindowObserver {
    private let onChange: @MainActor (Bool) -> Void
    private var pids: Set<pid_t> = []
    private var observers: [pid_t: AXObserver] = [:]
    private var hasMeetingWindow = false
    private var rescanTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var systemWideTimeoutSet = false

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    func setTeamsPIDs(_ newPIDs: Set<pid_t>) {
        let removed = pids.subtracting(newPIDs)
        pids = newPIDs
        for pid in removed { detach(pid) }
        if pids.isEmpty {
            pollTask?.cancel()
            pollTask = nil
            rescanTask?.cancel()
            rescanTask = nil
            publish(false)
            return
        }
        attachAll()
        startPollingIfNeeded()
        markDirty()
    }

    func stop() {
        for pid in Array(observers.keys) { detach(pid) }
        pollTask?.cancel()
        pollTask = nil
        rescanTask?.cancel()
        rescanTask = nil
    }

    // MARK: - AXObserver

    private func attachAll() {
        guard AXIsProcessTrusted() else { return }
        if !systemWideTimeoutSet {
            AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Constants.TeamsDetection.axMessagingTimeout)
            systemWideTimeoutSet = true
        }
        for pid in pids where observers[pid] == nil {
            attach(pid)
        }
    }

    private func attach(_ pid: pid_t) {
        var observer: AXObserver?
        guard AXObserverCreate(pid, Self.axCallback, &observer) == .success, let observer else {
            Log.teams.debug("AXObserverCreate failed for pid \(pid)")
            return
        }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, Constants.TeamsDetection.axMessagingTimeout)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification,
            kAXTitleChangedNotification, kAXUIElementDestroyedNotification,
        ] {
            AXObserverAddNotification(observer, application, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func detach(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private static let axCallback: AXObserverCallback = { _, _, _, refcon in
        guard let refcon else { return }
        let observer = Unmanaged<TeamsWindowObserver>.fromOpaque(refcon).takeUnretainedValue()
        MainActor.assumeIsolated { observer.markDirty() }
    }

    // MARK: - Rescan

    private func markDirty() {
        guard rescanTask == nil else { return }
        rescanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.TeamsDetection.windowRescanCoalesce))
            guard !Task.isCancelled, let self else { return }
            self.rescanTask = nil
            let pids = self.pids
            guard !pids.isEmpty, AXIsProcessTrusted() else {
                self.publish(false)
                return
            }
            let found = await Task.detached(priority: .utility) { Self.scanForMeetingWindow(pids: pids) }.value
            self.publish(found)
        }
    }

    private func publish(_ value: Bool) {
        guard value != hasMeetingWindow else { return }
        hasMeetingWindow = value
        Log.teams.debug("Teams meeting window present: \(value)")
        onChange(value)
    }

    private func startPollingIfNeeded() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    for: .seconds(Constants.TeamsDetection.windowFallbackPollInterval),
                    tolerance: .seconds(Constants.TeamsDetection.windowFallbackPollTolerance)
                )
                guard !Task.isCancelled, let self else { return }
                self.attachAll()  // picks up Accessibility granted after launch
                self.markDirty()
            }
        }
    }

    /// Off-main: enumerates the windows of each Teams process and classifies titles.
    nonisolated static func scanForMeetingWindow(pids: Set<pid_t>) -> Bool {
        for pid in pids {
            let application = AXUIElementCreateApplication(pid)
            var windowsValue: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                let windows = windowsValue as? [AXUIElement]
            else { continue }
            for window in windows {
                var titleValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                    let title = titleValue as? String
                else { continue }
                if TeamsWindowClassifier.isMeetingWindow(title: title) {
                    Log.teams.debug("Meeting window: \(title, privacy: .private)")
                    return true
                }
            }
        }
        return false
    }
}
