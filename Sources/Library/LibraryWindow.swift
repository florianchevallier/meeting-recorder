import AppKit
import SwiftUI

/// Owns the Library NSWindow (created once): every recording, searchable, with
/// its transcript, live transcript and meeting info.
@MainActor
final class LibraryWindowController: NSObject, NSWindowDelegate {

    private let calendar: CalendarMonitor
    private let transcription: TranscriptionCoordinator
    private let settings: SettingsStore
    private let speakerNamesWindowController: SpeakerNamesWindowController
    private var window: NSWindow?

    init(
        calendar: CalendarMonitor,
        transcription: TranscriptionCoordinator,
        settings: SettingsStore,
        speakerNamesWindowController: SpeakerNamesWindowController
    ) {
        self.calendar = calendar
        self.transcription = transcription
        self.settings = settings
        self.speakerNamesWindowController = speakerNamesWindowController
        super.init()
    }

    func show() {
        calendar.refresh()
        let window = self.window ?? makeWindow()
        // A regular app while the window is open (Dock icon, ⌘-Tab), back to the menu bar when
        // it closes. The cooperative `activate()` is declined after a popover click: the window
        // showed up but the keyboard stayed in the previous app (dead search field).
        NSApp.setActivationPolicy(.regular)
        (NSApp as any ForceActivating).forceActivate()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
    }

    private func makeWindow() -> NSWindow {
        let rootView = LibraryView(
            calendar: calendar,
            transcription: transcription,
            settings: settings,
            onEditSpeakers: { [weak self] in self?.speakerNamesWindowController.show(for: $0) }
        )
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = L10n.libraryWindowTitle
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 920, height: 620))
        window.setFrameAutosaveName("MeetyLibrary")
        if window.frame.origin == .zero { window.center() }
        return window
    }
}

// MARK: - Views

private struct LibraryView: View {
    let calendar: CalendarMonitor
    let transcription: TranscriptionCoordinator
    let settings: SettingsStore
    let onEditSpeakers: (URL) -> Void

    @State private var entries: [LibraryEntry] = []
    @State private var hits: [RecordingLibrary.Hit] = []
    @State private var query = ""
    @State private var selection: URL?
    /// Bumped after an edit from the detail (participants, event) that keeps the file list.
    @State private var edits = 0

    // The keys' fields are only read by the synthesized `Equatable` that `.task(id:)`
    // compares, which Periphery can't see: hence the ignores.

    /// Reload when a recording appears, a transcription finishes (its `.txt` changes) or after an edit.
    private struct ReloadKey: Equatable {
        // periphery:ignore
        let recordings: [URL]
        // periphery:ignore
        let transcribing: URL?
        // periphery:ignore
        let edits: Int
    }

    private struct SearchKey: Equatable {
        // periphery:ignore
        let query: String
        // periphery:ignore
        let entries: [LibraryEntry]
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(days, id: \.day) { section in
                    Section(section.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())) {
                        ForEach(section.hits) { hit in
                            LibraryRow(hit: hit).tag(hit.entry.audio)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: L10n.librarySearchPrompt)
            .overlay {
                if hits.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? L10n.libraryEmpty : L10n.libraryNoResults,
                        systemImage: query.isEmpty ? "waveform" : "magnifyingglass")
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            if let entry = entries.first(where: { $0.audio == selection }) {
                LibraryDetail(
                    entry: entry,
                    query: query,
                    calendar: calendar,
                    transcription: transcription,
                    canTranscribe: !settings.apiBaseURL.isEmpty,
                    onEditSpeakers: onEditSpeakers,
                    onEdited: { audio in
                        selection = audio
                        edits += 1
                        calendar.refresh()
                    }
                )
                .id(entry.audio)
            } else {
                ContentUnavailableView(L10n.libraryNoSelection, systemImage: "waveform")
            }
        }
        .task(id: ReloadKey(recordings: calendar.recordings, transcribing: transcription.current, edits: edits)) {
            let recordings = calendar.recordings
            entries = await Task.detached { RecordingLibrary.load(recordings) }.value
        }
        .task(id: SearchKey(query: query, entries: entries)) {
            let (entries, query) = (entries, query)
            hits = await Task.detached { RecordingLibrary.search(entries, query: query) }.value
        }
    }

    private var days: [(day: Date, hits: [RecordingLibrary.Hit])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: hits) { calendar.startOfDay(for: $0.entry.date ?? .distantPast) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }
}

private struct LibraryRow: View {
    let hit: RecordingLibrary.Hit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(hit.entry.title ?? L10n.calendarUntitledEvent)
                .font(.body.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 6) {
                if let date = hit.entry.date {
                    Text(date.formatted(date: .omitted, time: .shortened))
                }
                if hit.entry.transcript != nil {
                    Image(systemName: "doc.text").help(L10n.libraryTabTranscript)
                }
                if hit.entry.live != nil {
                    Image(systemName: "captions.bubble").help(L10n.libraryTabLive)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let snippet = hit.snippet {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// `activate(ignoringOtherApps:)` is deprecated since macOS 14 but is the only call that brings an
/// LSUIElement app forward from its status item (measured on macOS 27). Called through a protocol
/// so the deprecation stays local and `-warnings-as-errors` builds pass.
private protocol ForceActivating {
    func forceActivate()
}

extension NSApplication: ForceActivating {
    @available(macOS, deprecated: 14.0, message: "Only for windows that need the keyboard from the menu bar")
    fileprivate func forceActivate() {
        activate(ignoringOtherApps: true)
    }
}
