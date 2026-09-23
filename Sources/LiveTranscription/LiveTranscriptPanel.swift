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
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.liveWindowTitle
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: Constants.Live.panelMinWidth, height: Constants.Live.panelMinHeight)

        // The whole panel is one sheet of Liquid Glass; the SwiftUI content paints no background.
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = Constants.Live.panelCornerRadius
        glass.contentView = NSHostingView(rootView: LiveTranscriptView(live: live))
        panel.contentView = glass

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

    /// Follow the tail: stays true until the user scrolls up, back to true at the bottom.
    @State private var following = true
    @State private var isAtBottom = true
    @State private var copied = false

    private static let titleBarHeight: CGFloat = 30

    var body: some View {
        // Full-size content: the header shares the title bar row with the window buttons,
        // and the transcript fades out as it scrolls under it.
        ZStack(alignment: .top) {
            if live.transcript.isEmpty {
                placeholder.padding(.top, Self.titleBarHeight)
            } else {
                transcriptList
            }
            header
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: Constants.Live.panelMinWidth, minHeight: Constants.Live.panelMinHeight)
    }

    // MARK: Header (sits in the transparent title bar, right of the window buttons)

    private var header: some View {
        HStack(spacing: 8) {
            StatusBadge(status: live.status)
            Spacer(minLength: 8)
            Menu {
                Button(L10n.liveCopyAll) { copy(lastMinutes: nil) }
                Divider()
                ForEach(Constants.Live.copyWindowsMinutes, id: \.self) { minutes in
                    Button(L10n.liveCopyLastMinutes(minutes)) { copy(lastMinutes: minutes) }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .help(L10n.liveCopy)
            .disabled(live.transcript.isEmpty)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.leading, 76)  // clear the close / zoom buttons
        .padding(.trailing, 12)
        .frame(height: Self.titleBarHeight)
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
                .symbolEffect(.variableColor.iterative, isActive: live.status == .running)
            Text(live.status == .idle ? L10n.livePlaceholderIdle : L10n.livePlaceholderListening)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Transcript

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(live.transcript.segments) { segment in
                        SegmentRow(segment: segment)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .animation(.smooth(duration: 0.25), value: live.transcript)
            }
            .contentMargins(.top, Self.titleBarHeight + 6, for: .scrollContent)
            .contentMargins(.top, Self.titleBarHeight, for: .scrollIndicators)
            .defaultScrollAnchor(.bottom)
            .mask {
                VStack(spacing: 0) {
                    Color.clear.frame(height: Self.titleBarHeight - 6)
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 18)
                    Color.black
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y
            } action: { old, new in
                // We only ever scroll down, and text growing under the viewport doesn't move the
                // offset: moving up is the user (wheel or trackpad) wanting to reread.
                if new < old - 1 { following = false }
            }
            .onChange(of: isAtBottom) {
                if isAtBottom { following = true }
            }
            .onChange(of: live.transcript) {
                guard following else { return }
                // After this update is laid out, pin the tail.
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.smooth(duration: 0.2)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            .overlay(alignment: .bottom) {
                if !following {
                    Button {
                        following = true
                        withAnimation(.smooth) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    } label: {
                        Label(L10n.liveJumpToLatest, systemImage: "arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.bottom, 12)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: following)
        }
    }

    private static let bottomID = "bottom"

    private func copy(lastMinutes: Int?) {
        let text = live.transcript.plainText(lastMinutes: lastMinutes)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// Live / preparing / idle / unavailable, as a dot + label (a status, so a tinted fill, not glass).
private struct StatusBadge: View {
    let status: LiveTranscriptionCoordinator.Status

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(color)
                .symbolEffect(.pulse, options: .repeating, isActive: status == .running)
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(status == .running ? .primary : .secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: .capsule)
        .help(text)
    }

    private var text: String {
        switch status {
        case .idle: return L10n.liveStatusIdle
        case .preparing: return L10n.liveStatusPreparing
        case .running: return L10n.liveStatusRunning
        case .unavailable(let message): return message
        }
    }

    private var color: Color {
        switch status {
        case .idle: return .gray
        case .preparing: return .orange
        case .running: return .red
        case .unavailable: return .yellow
        }
    }
}

private struct SegmentRow: View {
    let segment: LiveTranscript.Segment

    private var tint: Color { segment.speaker == .me ? .blue : .purple }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint.gradient)
                    .frame(width: 7, height: 7)
                Text(segment.speaker.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(LiveTranscript.timestamp(segment.start))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(segment.text)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundStyle(segment.isFinal ? .primary : .secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
