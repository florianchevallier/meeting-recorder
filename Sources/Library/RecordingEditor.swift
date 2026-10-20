import os
import Foundation

/// Edits a finished recording from the Library: its title (files renamed with it),
/// its calendar event and the participants of that event. Every change lands in
/// `.meeting.json`, which the next transcription reads for its hints, and the
/// `.txt` header is re-rendered right away.
enum RecordingEditor {

    enum EditError: LocalizedError {
        case nameTaken(String)

        var errorDescription: String? {
            switch self {
            case .nameTaken(let name): return L10n.libraryErrorNameTaken(name)
            }
        }
    }

    /// Every file of the recording: the audio and all its sidecars.
    static func files(of audio: URL) -> [URL] {
        let base = RecordingsMigration.groupKey(audio)
        let directory = audio.deletingLastPathComponent()
        let all = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return all.filter { RecordingsMigration.groupKey($0) == base }
    }

    /// `meeting_<timestamp>_<title>.m4a` for the same timestamp; nil if `audio` isn't a recording.
    static func renamed(_ audio: URL, to title: String) -> URL? {
        let prefix = Constants.Permissions.recordingPrefix + "_"
        let name = audio.lastPathComponent
        let stamp = name.dropFirst(prefix.count).prefix(Constants.DateFormat.timestamp.count)
        guard name.hasPrefix(prefix), stamp.count == Constants.DateFormat.timestamp.count else { return nil }
        let suffix = FileSystemUtilities.sanitizedFilenameComponent(title).map { "_" + $0 } ?? ""
        return audio.deletingLastPathComponent()
            .appendingPathComponent("\(prefix)\(stamp)\(suffix).\(audio.pathExtension)")
    }

    /// Renames every file of the recording and the event title. Returns the new audio URL.
    @discardableResult
    static func rename(_ audio: URL, to title: String) throws -> URL {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = renamed(audio, to: title) ?? audio
        let oldBase = RecordingsMigration.groupKey(audio)
        let newBase = RecordingsMigration.groupKey(target)
        let moves =
            target == audio
            ? []
            : files(of: audio).map { file in
                (
                    file,
                    file.deletingLastPathComponent()
                        .appendingPathComponent(newBase + file.lastPathComponent.dropFirst(oldBase.count))
                )
            }
        // Check every name first: a half-renamed recording would split its sidecars.
        if let clash = moves.first(where: { FileManager.default.fileExists(atPath: $0.1.path) }) {
            throw EditError.nameTaken(clash.1.lastPathComponent)
        }
        if let metadata = try? MeetingMetadata.read(forRecording: audio), metadata.event.title != title {
            try MeetingMetadata(recordingStartedAt: metadata.recordingStartedAt, event: metadata.event.retitled(title))
                .write(nextTo: audio)
        }
        for (from, to) in moves {
            try FileManager.default.moveItem(at: from, to: to)
        }
        if !moves.isEmpty {
            Log.app.info("Recording renamed to \(target.lastPathComponent, privacy: .private)")
        }
        rerender(target)
        return target
    }

    /// Links the recording to `event` (replacing any previous one) and renames it after it.
    @discardableResult
    static func link(_ audio: URL, to event: CalendarEvent) throws -> URL {
        let startedAt = CalendarMatcher.recordingDate(fromFilename: audio.lastPathComponent) ?? event.start
        try MeetingMetadata(recordingStartedAt: startedAt, event: event).write(nextTo: audio)
        return try rename(audio, to: event.title)
    }

    /// Drops `participant` from the event (organizer or attendee, matched like `expectedParticipants`).
    static func remove(_ participant: Participant, from audio: URL) throws {
        let metadata = try MeetingMetadata.read(forRecording: audio)
        try MeetingMetadata(
            recordingStartedAt: metadata.recordingStartedAt, event: metadata.event.removing(participant)
        )
        .write(nextTo: audio)
        rerender(audio)
    }

    /// Refreshes the `.txt` header (title, participants) when there is a transcript.
    private static func rerender(_ audio: URL) {
        guard FileManager.default.fileExists(atPath: RecordingFiles(audio: audio).transcriptJSON.path) else { return }
        do {
            try TranscriptFiles.writeText(for: audio)
        } catch {
            Log.app.error("Transcript not re-rendered: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension CalendarEvent {
    func retitled(_ title: String) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title, start: start, end: end, organizer: organizer, attendees: attendees,
            meetingURL: meetingURL)
    }

    func removing(_ participant: Participant) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title, start: start, end: end,
            organizer: organizer?.key == participant.key ? nil : organizer,
            attendees: attendees.filter { $0.key != participant.key },
            meetingURL: meetingURL)
    }
}
