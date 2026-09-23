import Cocoa
import Observation
import SwiftUI

/// Floating, non-activating panel showing the live transcript. Created once;
/// opens itself when a live session starts (clicking it never steals focus
/// from the meeting app).
@MainActor
final class LiveTranscriptPanelController {

    private var panel: NSPanel?
    private var sessionTask: Task<Void, Never>?
    private let live: LiveTranscriptionCoordinator

    init(live: LiveTranscriptionCoordinator) {
        self.live = live
    }

    /// Shows the panel at the start of every live session.
    func start() {
        let live = self.live
        sessionTask = Task { [weak self] in
            for await count in Observations({ live.sessionCount }) where count > 0 {
                self?.show()
            }
        }
    }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0, y: 0, width: Constants.Live.panelInitialWidth, height: Constants.Live.panelInitialHeight),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.liveWindowTitle
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: Constants.Live.panelMinWidth, height: Constants.Live.panelMinHeight)
        panel.contentViewController = NSHostingController(rootView: LiveTranscriptView(live: live))
        if !panel.setFrameUsingName(Constants.Live.panelAutosaveName) {
            panel.center()
        }
        panel.setFrameAutosaveName(Constants.Live.panelAutosaveName)
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

// MARK: - View

struct LiveTranscriptView: View {
    let live: LiveTranscriptionCoordinator

    @State private var isAtBottom = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if live.transcript.isEmpty {
                placeholder
            } else {
                transcriptList
            }
        }
        .frame(minWidth: Constants.Live.panelMinWidth, minHeight: Constants.Live.panelMinHeight)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                copyTranscript()
            } label: {
                Label(L10n.liveCopy, systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(live.transcript.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "captions.bubble")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(live.status == .idle ? L10n.livePlaceholderIdle : L10n.livePlaceholderListening)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(live.transcript.segments) { segment in
                        SegmentRow(segment: segment)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(12)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 40
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            .onChange(of: live.transcript) {
                // Follow the conversation unless the user scrolled up to reread.
                if isAtBottom { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
    }

    private static let bottomID = "bottom"

    private var statusText: String {
        switch live.status {
        case .idle: return L10n.liveStatusIdle
        case .preparing: return L10n.liveStatusPreparing
        case .running: return L10n.liveStatusRunning
        case .unavailable(let message): return message
        }
    }

    private var statusColor: Color {
        switch live.status {
        case .idle: return .gray
        case .preparing: return .orange
        case .running: return .red
        case .unavailable: return .yellow
        }
    }

    private func copyTranscript() {
        let text = live.transcript.segments
            .map { "[\(LiveTranscript.timestamp($0.start))] \($0.speaker.label) : \($0.text)" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct SegmentRow: View {
    let segment: LiveTranscript.Segment

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(segment.speaker.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(segment.speaker == .me ? Color.blue : Color.purple)
                Text(LiveTranscript.timestamp(segment.start))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Text(segment.text)
                .font(.system(size: 13))
                .foregroundStyle(segment.isFinal ? .primary : .secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
