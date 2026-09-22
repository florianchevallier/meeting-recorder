import Foundation

/// Reads a recording's sidecars and (re)writes its `.txt` transcript. The only
/// place that joins the pure pieces (`SpeakerLabeler`, `TranscriptRenderer`)
/// with the file system.
enum TranscriptFiles {

    /// Everything needed to render or rename, loaded from disk.
    struct Document: Sendable {
        let files: RecordingFiles
        let transcript: Transcript
        let event: CalendarEvent?
        let activity: VoiceActivity?
        let manualNames: [String: String]

        /// Names shown in the text: manual ones, then the ones inferred from the
        /// microphone and the calendar.
        var names: [String: String] {
            SpeakerLabeler.names(
                for: transcript, activity: activity, event: event, manual: manualNames,
                selfFallbackName: L10n.transcriptSelfSpeaker)
        }
    }

    static func load(for audioURL: URL) throws -> Document {
        let files = RecordingFiles(audio: audioURL)
        return Document(
            files: files,
            transcript: try Transcript.decode(Data(contentsOf: files.transcriptJSON)),
            event: (try? MeetingMetadata.read(forRecording: audioURL))?.event,
            activity: try? VoiceActivity.read(from: files.voiceActivity),
            manualNames: (try? readNames(from: files.speakerNames)) ?? [:]
        )
    }

    /// Renders the `.txt` from `.transcript.json` and the other sidecars.
    static func writeText(for audioURL: URL) throws {
        let document = try load(for: audioURL)
        let text = TranscriptRenderer.render(
            document.transcript, names: document.names, header: header(for: document.event), labels: labels)
        try text.write(to: document.files.transcriptText, atomically: true, encoding: .utf8)
    }

    /// Saves the names typed by the user, then re-renders the text.
    static func saveNames(_ names: [String: String], for audioURL: URL) throws {
        let files = RecordingFiles(audio: audioURL)
        let cleaned = names.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter {
            !$0.value.isEmpty
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cleaned).write(to: files.speakerNames, options: .atomic)
        try writeText(for: audioURL)
    }

    // MARK: - Helpers

    private static func readNames(from url: URL) throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private static func header(for event: CalendarEvent?) -> TranscriptRenderer.Header? {
        guard let event else { return nil }
        return TranscriptRenderer.Header(
            title: event.title.isEmpty ? L10n.calendarUntitledEvent : event.title,
            date: event.start.formatted(date: .long, time: .shortened),
            participants: event.expectedParticipants.map(\.displayName)
        )
    }

    private static var labels: TranscriptRenderer.Labels {
        TranscriptRenderer.Labels(
            participants: L10n.transcriptParticipants,
            unknownSpeaker: { L10n.transcriptUnknownSpeaker($0) }
        )
    }
}
