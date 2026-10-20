import AppKit
import SwiftUI

/// Owns the Library NSWindow (created once): every recording, searchable, with
/// its transcript, live transcript and meeting info.
@MainActor
final class LibraryWindowController {

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
    }

    func show() {
        calendar.refresh()
        let window = self.window ?? makeWindow()
        window.makeKeyAndOrderFront(nil)
        // An LSUIElement app opened from its popover isn't active yet: `activate()` alone may
        // leave the window behind the frontmost app.
        window.orderFrontRegardless()
        NSApp.activate()
        self.window = window
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

    /// Reload when a recording appears, a transcription finishes (its `.txt` changes) or after an edit.
    private struct ReloadKey: Equatable {
        let recordings: [URL]
        let transcribing: URL?
        let edits: Int
    }

    private struct SearchKey: Equatable {
        let query: String
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

private struct LibraryDetail: View {
    enum Tab: Hashable {
        case transcript, live, participants
    }

    let entry: LibraryEntry
    let query: String
    let calendar: CalendarMonitor
    let transcription: TranscriptionCoordinator
    let canTranscribe: Bool
    let onEditSpeakers: (URL) -> Void
    /// After a change on disk, with the (possibly renamed) audio URL.
    let onEdited: (URL) -> Void

    @State private var tab: Tab
    @State private var isRenaming = false
    @State private var draftTitle = ""
    @State private var dayEvents: [CalendarEvent] = []

    init(
        entry: LibraryEntry,
        query: String,
        calendar: CalendarMonitor,
        transcription: TranscriptionCoordinator,
        canTranscribe: Bool,
        onEditSpeakers: @escaping (URL) -> Void,
        onEdited: @escaping (URL) -> Void
    ) {
        self.entry = entry
        self.query = query
        self.calendar = calendar
        self.transcription = transcription
        self.canTranscribe = canTranscribe
        self.onEditSpeakers = onEditSpeakers
        self.onEdited = onEdited
        _tab = State(initialValue: entry.transcript != nil ? .transcript : entry.live != nil ? .live : .participants)
    }

    /// Files move or change under a transcription in flight: no edits meanwhile.
    private var isBusy: Bool { transcription.isPending(entry.audio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Picker("", selection: $tab) {
                if entry.transcript != nil { Text(L10n.libraryTabTranscript).tag(Tab.transcript) }
                if entry.live != nil { Text(L10n.libraryTabLive).tag(Tab.live) }
                Text(L10n.libraryTabParticipants).tag(Tab.participants)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            ScrollView {
                content
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
        .padding(20)
        .task(id: entry.audio) {
            dayEvents = entry.date.map { calendar.events(onDayOf: $0) } ?? []
        }
        .alert(L10n.libraryRenameTitle, isPresented: $isRenaming) {
            TextField(L10n.libraryRenamePlaceholder, text: $draftTitle)
            Button(L10n.libraryRename) { edit { try RecordingEditor.rename(entry.audio, to: draftTitle) } }
                .keyboardShortcut(.defaultAction)
            Button(L10n.libraryCancel, role: .cancel) {}
        } message: {
            Text(L10n.libraryRenameMessage)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.title ?? L10n.calendarUntitledEvent)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    Button(L10n.libraryRename, systemImage: "pencil") {
                        draftTitle = entry.title ?? ""
                        isRenaming = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(isBusy)
                }
                HStack(spacing: 10) {
                    if let date = entry.date {
                        Text(date.formatted(date: .complete, time: .shortened))
                    }
                    if !entry.participants.isEmpty {
                        Button(L10n.calendarParticipants(entry.participants.count), systemImage: "person.2") {
                            tab = .participants
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            actions
        }
    }

    private var actions: some View {
        let files = RecordingFiles(audio: entry.audio)
        return HStack(spacing: 8) {
            Button(L10n.calendarPlayRecording, systemImage: "play.fill") { NSWorkspace.shared.open(entry.audio) }
            Button(L10n.calendarShowInFinder, systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([entry.audio])
            }
            linkMenu
            if FileManager.default.fileExists(atPath: files.transcriptJSON.path) {
                Button(L10n.calendarEditSpeakers, systemImage: "person.crop.circle.badge.questionmark") {
                    onEditSpeakers(entry.audio)
                }
            }
            if isBusy {
                ProgressView().controlSize(.small).help(L10n.calendarTranscriptionPending)
            } else if canTranscribe {
                transcribeButton
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private var transcribeButton: some View {
        let again = entry.transcript != nil
        return Button(
            again ? L10n.calendarRetranscribe : L10n.calendarTranscribe,
            systemImage: again ? "arrow.clockwise" : "waveform"
        ) { transcription.enqueue(entry.audio) }
    }

    /// The day's calendar meetings, closest first; picking one re-links and renames the recording.
    private var linkMenu: some View {
        Menu {
            if dayEvents.isEmpty {
                Text(L10n.libraryLinkEventNone)
            }
            ForEach(dayEvents) { event in
                Button {
                    edit { try RecordingEditor.link(entry.audio, to: event) }
                } label: {
                    let time = event.start.formatted(date: .omitted, time: .shortened)
                    let isCurrent = event.id == entry.event?.id
                    Label("\(time)  \(event.title)", systemImage: isCurrent ? "checkmark" : "calendar")
                }
            }
        } label: {
            Label(L10n.libraryLinkEvent, systemImage: "calendar.badge.clock")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L10n.libraryLinkEvent)
        .disabled(isBusy)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .transcript: Text(highlighted(entry.transcript ?? ""))
        case .live: Text(highlighted(entry.live ?? ""))
        case .participants: participants
        }
    }

    private var participants: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let event = entry.event, !event.expectedParticipants.isEmpty {
                ForEach(event.expectedParticipants, id: \.key) { participant in
                    ParticipantRow(participant: participant, isOrganizer: participant.key == event.organizer?.key) {
                        edit {
                            try RecordingEditor.remove(participant, from: entry.audio)
                            return entry.audio
                        }
                    }
                    .disabled(isBusy)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.libraryParticipantsHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if canTranscribe && !isBusy {
                        transcribeButton.buttonStyle(.bordered)
                    }
                }
                .padding(.top, 6)
            } else {
                Text(L10n.libraryParticipantsEmpty).foregroundStyle(.secondary)
            }
            Text(L10n.libraryFile).font(.headline).padding(.top, 12)
            Text(entry.audio.path).font(.callout.monospaced()).foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    /// Runs a file edit, reports failures, then tells the list (new URL after a rename).
    private func edit(_ change: () throws -> URL) {
        do {
            onEdited(try change())
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// `text` with every occurrence of each query word highlighted.
    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        for word in query.split(whereSeparator: \.isWhitespace) {
            var start = result.startIndex
            while let range = result[start...].range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
                result[range].backgroundColor = .yellow.opacity(0.4)
                start = range.upperBound
            }
        }
        return result
    }
}

private struct ParticipantRow: View {
    let participant: Participant
    let isOrganizer: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(initials)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.tint))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(participant.displayName).font(.body.weight(.medium))
                    if participant.isCurrentUser { badge(L10n.libraryParticipantMe) }
                    if isOrganizer { badge(L10n.libraryParticipantOrganizer) }
                }
                if let email = participant.email, email != participant.displayName {
                    Text(email).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Button(L10n.libraryParticipantRemove, systemImage: "minus.circle", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help(L10n.libraryParticipantRemove)
        }
    }

    private var initials: String {
        let words = participant.displayName.split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "@" })
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    private var status: String? {
        switch participant.status {
        case .accepted: L10n.libraryParticipantAccepted
        case .tentative: L10n.libraryParticipantTentative
        case .pending: L10n.libraryParticipantPending
        case .declined, .unknown: nil
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(.quaternary))
    }
}
