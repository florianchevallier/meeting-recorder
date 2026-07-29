import Cocoa
import SwiftUI

/// Owns the NSStatusItem and its popover. Pure AppKit glue:
/// all recording state lives in `RecordingCoordinator`.
@MainActor
final class StatusBarController {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private let coordinator: RecordingCoordinator
    private let permissionMonitor: PermissionMonitor
    private let settingsWindowController: SettingsWindowController

    init(
        coordinator: RecordingCoordinator,
        permissionMonitor: PermissionMonitor,
        settingsWindowController: SettingsWindowController
    ) {
        self.coordinator = coordinator
        self.permissionMonitor = permissionMonitor
        self.settingsWindowController = settingsWindowController
    }

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        let menu = StatusBarMenu(
            coordinator: coordinator,
            permissionMonitor: permissionMonitor,
            onOpenSettings: { [weak self] in
                self?.settingsWindowController.show(tab: .general)
            }
        )

        let popover = NSPopover()
        popover.contentSize = NSSize(width: Constants.UI.menuWidth, height: Constants.UI.menuHeight)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: menu)
        self.popover = popover

        observeState()
    }

    func tearDown() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover = nil
    }

    // MARK: - Popover

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button,
              let popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Icon

    private func observeState() {
        withObservationTracking {
            _ = coordinator.state
            _ = coordinator.isTeamsMeetingDetected
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateIcon()
                self.observeState()
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }

        let description: String
        let iconName: String

        if coordinator.isStopping {
            description = L10n.statusFinishing
            iconName = "hourglass.circle"
        } else if coordinator.isRecording {
            description = L10n.statusRecording
            iconName = "record.circle.fill"
        } else if coordinator.isTeamsMeetingDetected {
            description = L10n.statusTeamsDetected
            iconName = "video.circle"
        } else {
            description = L10n.statusReady
            iconName = "record.circle"
        }

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: description)
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
        button.alphaValue = 1.0
        button.toolTip = description
    }
}
