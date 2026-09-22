import Cocoa
import SwiftUI
import Observation

/// Pure mapping from coordinator state to the status-bar icon. Testable.
enum IconState: CaseIterable, Sendable {
    case ready
    case teamsDetected
    case recording
    case finishing

    init(isStopping: Bool, isRecording: Bool, isTeamsMeetingDetected: Bool) {
        if isStopping {
            self = .finishing
        } else if isRecording {
            self = .recording
        } else if isTeamsMeetingDetected {
            self = .teamsDetected
        } else {
            self = .ready
        }
    }

    var symbolName: String {
        switch self {
        case .ready: return "record.circle"
        case .teamsDetected: return "video.circle"
        case .recording: return "record.circle.fill"
        case .finishing: return "hourglass.circle"
        }
    }

    var description: String {
        switch self {
        case .ready: return L10n.statusReady
        case .teamsDetected: return L10n.statusTeamsDetected
        case .recording: return L10n.statusRecording
        case .finishing: return L10n.statusFinishing
        }
    }
}

/// Owns the NSStatusItem and its popover. Pure AppKit glue:
/// all recording state lives in `RecordingCoordinator`.
@MainActor
final class StatusBarController {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var icons: [IconState: NSImage] = [:]
    private var iconTask: Task<Void, Never>?

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
        icons = Dictionary(
            uniqueKeysWithValues: IconState.allCases.map { state in
                let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.description)
                image?.size = NSSize(width: 18, height: 18)
                image?.isTemplate = true
                return (state, image ?? NSImage())
            })

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
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

        // Let SwiftUI drive the popover size. A fixed `contentSize` taller than
        // the view makes AppKit anchor a 360 pt window under the status item and
        // then shrink it from the top, leaving a gap between the bar and the arrow.
        let hosting = NSHostingController(rootView: menu)
        hosting.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
        self.popover = popover

        let coordinator = self.coordinator
        iconTask = Task { [weak self] in
            for await state in Observations({
                IconState(
                    isStopping: coordinator.isStopping,
                    isRecording: coordinator.isRecording,
                    isTeamsMeetingDetected: coordinator.isTeamsMeetingDetected
                )
            }) {
                self?.apply(state)
            }
        }
    }

    func tearDown() {
        iconTask?.cancel()
        iconTask = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover = nil
    }

    // MARK: - Popover

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Icon

    private func apply(_ state: IconState) {
        guard let button = statusItem?.button else { return }
        button.image = icons[state]
        button.toolTip = state.description
    }
}
