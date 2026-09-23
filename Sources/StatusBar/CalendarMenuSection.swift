import AppKit
import SwiftUI

/// Today's meetings in the popover. The agenda is recomputed from the
/// monitor's snapshot once a minute (upcoming → past, "in N min"); the
/// calendar itself is only re-read on events (see `CalendarMonitor`).
struct CalendarMenuSection: View {
    let calendar: CalendarMonitor
    let permissionMonitor: PermissionMonitor
    let settings: SettingsStore
    let transcription: TranscriptionCoordinator
    let onEditSpeakers: (URL) -> Void

    var body: some View {
        if settings.calendarEnabled {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch permissionMonitor.calendar {
        case .granted:
            TimelineView(.everyMinute) { context in
                AgendaList(
                    agenda: calendar.agenda(at: context.date),
                    now: context.date,
                    actions: RecordingActions(
                        canTranscribe: !settings.apiBaseURL.isEmpty,
                        isPending: transcription.isPending,
                        transcribe: transcription.enqueue,
                        editSpeakers: onEditSpeakers
                    )
                )
            }
        case .denied:
            ConnectRow { permissionMonitor.openSystemSettings(for: .calendar) }
        case .notDetermined, .unknownUntilFirstUse:
            ConnectRow { Task { await permissionMonitor.requestCalendar() } }
        }
    }
}

// MARK: - Connect

private struct ConnectRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.calendarConnect, systemImage: "calendar.badge.plus")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
}

// MARK: - Agenda

/// What a past meeting row can do with its recording.
private struct RecordingActions {
    let canTranscribe: Bool
    let isPending: (URL) -> Bool
    let transcribe: (URL) -> Void
    let editSpeakers: (URL) -> Void
}

private struct AgendaList: View {
    let agenda: CalendarAgenda
    let now: Date
    let actions: RecordingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: L10n.calendarSectionTitle, icon: "calendar")

            if agenda.upcoming.isEmpty {
                Text(L10n.calendarEmpty)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ForEach(agenda.upcoming) { entry in
                EventRow(entry: entry, now: now, isPast: false, recordingActions: actions)
            }

            if !agenda.past.isEmpty {
                SectionLabel(title: L10n.calendarPastTitle, icon: "clock.arrow.circlepath")
                    .padding(.top, 4)
                ForEach(agenda.past) { entry in
                    EventRow(entry: entry, now: now, isPast: true, recordingActions: actions)
                }
            }
        }
    }
}

private struct SectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title.uppercased(), systemImage: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
    }
}

private struct EventRow: View {
    let entry: CalendarAgenda.Entry
    let now: Date
    let isPast: Bool
    let recordingActions: RecordingActions

    private var event: CalendarEvent { entry.event }
    private var recording: URL? { entry.recordings.last }

    var body: some View {
        HStack(spacing: 8) {
            Text(event.start.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title.isEmpty ? L10n.calendarUntitledEvent : event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(subtitle.isLive ? Color.red : Color.secondary)
                        .lineLimit(1)
                }
            }
            .help(participantsTooltip)

            Spacer(minLength: 4)

            actions
        }
    }

    // MARK: Subtitle

    private var subtitle: (text: String, isLive: Bool)? {
        var parts: [String] = []
        var isLive = false
        if !isPast {
            if event.contains(now) {
                parts.append(L10n.calendarInProgress)
                isLive = true
            } else {
                let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
                if minutes <= 60 { parts.append(L10n.calendarStartsIn(minutes)) }
            }
        }
        if let count = event.expectedSpeakerCount {
            parts.append(L10n.calendarParticipants(count))
        }
        return parts.isEmpty ? nil : (parts.joined(separator: " · "), isLive)
    }

    private var participantsTooltip: String {
        event.expectedParticipants.map(\.displayName).joined(separator: "\n")
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            if !isPast, let url = event.meetingURL {
                IconButton(icon: "video.fill", help: L10n.calendarJoin) { NSWorkspace.shared.open(url) }
            }
            if let recording {
                IconButton(icon: "play.fill", help: L10n.calendarPlayRecording) {
                    NSWorkspace.shared.open(recording)
                }
                let files = RecordingFiles(audio: recording)
                let hasTranscript = FileManager.default.fileExists(atPath: files.transcriptText.path)
                if hasTranscript {
                    IconButton(icon: "doc.text", help: L10n.calendarOpenTranscript) {
                        NSWorkspace.shared.open(files.transcriptText)
                    }
                } else if FileManager.default.fileExists(atPath: files.liveTranscript.path) {
                    IconButton(icon: "captions.bubble", help: L10n.calendarOpenLiveTranscript) {
                        NSWorkspace.shared.open(files.liveTranscript)
                    }
                }
                if FileManager.default.fileExists(atPath: files.transcriptJSON.path) {
                    IconButton(icon: "person.2", help: L10n.calendarEditSpeakers) {
                        recordingActions.editSpeakers(recording)
                    }
                }
                if recordingActions.isPending(recording) {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 18, height: 18)
                        .help(L10n.calendarTranscriptionPending)
                } else if recordingActions.canTranscribe {
                    IconButton(
                        icon: hasTranscript ? "arrow.clockwise" : "waveform",
                        help: hasTranscript ? L10n.calendarRetranscribe : L10n.calendarTranscribe
                    ) {
                        recordingActions.transcribe(recording)
                    }
                }
                IconButton(icon: "folder", help: L10n.calendarShowInFinder) {
                    NSWorkspace.shared.activateFileViewerSelecting([recording])
                }
            }
        }
    }
}

private struct IconButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}
