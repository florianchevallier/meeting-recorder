import os
import Cocoa
import SwiftUI

/// Selected tab of the settings window, shared with the SwiftUI root so the
/// controller can switch tabs without replacing the root view.
@MainActor
@Observable
final class SettingsWindowModel {
    var selectedTab: SettingsWindow.SettingsTab = .general
}

/// Owns the settings NSWindow: creation, reuse, tab selection, close callback.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let model = SettingsWindowModel()

    private let settings: SettingsStore
    private let permissionMonitor: PermissionMonitor
    private let calendar: CalendarMonitor

    /// Invoked when the user closes the window (used by onboarding).
    var onClose: (() -> Void)?

    static let windowIdentifier = NSUserInterfaceItemIdentifier("settingsWindow")

    init(settings: SettingsStore, permissionMonitor: PermissionMonitor, calendar: CalendarMonitor) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.calendar = calendar
    }

    func show(tab: SettingsWindow.SettingsTab = .general) {
        Log.settings.debug("Opening settings window (tab: \(tab.rawValue))")
        model.selectedTab = tab

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let rootView = SettingsWindow(
            settings: settings, permissionMonitor: permissionMonitor, calendar: calendar, model: model)
        let hostingController = NSHostingController(rootView: rootView)

        let newWindow = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Constants.UI.windowInitialWidth,
                height: Constants.UI.windowInitialHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = L10n.settingsWindowTitle
        newWindow.identifier = Self.windowIdentifier
        newWindow.contentViewController = hostingController
        newWindow.minSize = NSSize(width: Constants.UI.windowMinWidth, height: Constants.UI.windowMinHeight)
        newWindow.maxSize = NSSize(width: Constants.UI.windowMaxWidth, height: Constants.UI.windowMaxHeight)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()

        window = newWindow
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated { onClose?() }
    }
}
