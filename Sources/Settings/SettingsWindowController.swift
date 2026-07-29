import Cocoa
import SwiftUI

/// Owns the settings NSWindow: creation, reuse, and tab selection.
///
/// Reuse is by window identifier only — the old code also matched the French
/// title, which created duplicate windows under non-French locales.
@MainActor
final class SettingsWindowController {

    private weak var window: NSWindow?

    private let settings: SettingsStore
    private let permissionMonitor: PermissionMonitor

    static let windowIdentifier = NSUserInterfaceItemIdentifier("settingsWindow")

    init(settings: SettingsStore, permissionMonitor: PermissionMonitor) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
    }

    func show(tab: SettingsWindow.SettingsTab = .general) {
        Logger.shared.info("Opening settings window (tab: \(tab.rawValue))", component: "SETTINGS")
        NSApp.activate(ignoringOtherApps: true)

        if let existing = NSApp.windows.first(where: { $0.identifier == Self.windowIdentifier }) {
            Logger.shared.debug("Reusing existing settings window", component: "SETTINGS")
            if let hostingController = existing.contentViewController as? NSHostingController<SettingsWindow> {
                hostingController.rootView = makeRootView(tab: tab)
            }
            existing.makeKeyAndOrderFront(nil)
            existing.center()
            window = existing
            return
        }

        Logger.shared.debug("Creating settings window", component: "SETTINGS")
        let hostingController = NSHostingController(rootView: makeRootView(tab: tab))

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
        newWindow.center()
        newWindow.minSize = NSSize(width: Constants.UI.windowMinWidth, height: Constants.UI.windowMinHeight)
        newWindow.maxSize = NSSize(width: Constants.UI.windowMaxWidth, height: Constants.UI.windowMaxHeight)
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    private func makeRootView(tab: SettingsWindow.SettingsTab) -> SettingsWindow {
        SettingsWindow(settings: settings, permissionMonitor: permissionMonitor, selectedTab: tab)
    }
}
