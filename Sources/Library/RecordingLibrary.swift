import Foundation

/// One recording with the text of its sidecars, as the Library window shows and searches it.
struct LibraryEntry: Identifiable, Sendable, Equatable {
    var id: URL { audio }
    let audio: URL
    /// Start of the recording, from its filename.
    let date: Date?
    /// Calendar event title, else the title in the filename; nil for untitled recordings.
    let title: String?
    /// Calendar event from `.meeting.json` (participants, edited copies included).
    let event: CalendarEvent?
    /// Rendered WhisperX transcript (`.txt`).
    let transcript: String?
    /// On-device transcript written while recording (`.live.md`).
    let live: String?

    var participants: [String] { event?.expectedParticipants.map(\.displayName) ?? [] }
}

/// Pure loading and full-text search over the recordings folder. No index: a few
/// hundred text files fit in memory and scan in milliseconds.
/// ponytail: switch to Core Spotlight or SQLite FTS if searching ever lags.
enum RecordingLibrary {

    enum Field: Sendable, Equatable {
        case title, participants, transcript, live
    }

    struct Hit: Identifiable, Sendable, Equatable {
        var id: URL { entry.audio }
        let entry: LibraryEntry
        /// Where the first query word was found (nil for an empty query).
        let field: Field?
        /// Text around the first match in the transcript or live text.
        let snippet: String?
    }

    /// Reads the sidecars of `recordings`, newest first. Blocking I/O: call off the main actor.
    static func load(_ recordings: [URL]) -> [LibraryEntry] {
        recordings
            .map { audio in
                let files = RecordingFiles(audio: audio)
                let event = (try? MeetingMetadata.read(forRecording: audio))?.event
                return LibraryEntry(
                    audio: audio,
                    date: CalendarMatcher.recordingDate(fromFilename: audio.lastPathComponent),
                    title: event.map(\.title).flatMap { $0.isEmpty ? nil : $0 }
                        ?? titleFromFilename(audio.lastPathComponent),
                    event: event,
                    transcript: try? String(contentsOf: files.transcriptText, encoding: .utf8),
                    live: try? String(contentsOf: files.liveTranscript, encoding: .utf8)
                )
            }
            // By start date, not by filename: `meeting_unified_…` (pre-0.6) would sort above every newer name.
            .sorted {
                ($0.date ?? .distantPast, $0.audio.lastPathComponent) > (
                    $1.date ?? .distantPast, $1.audio.lastPathComponent
                )
            }
    }

    /// `meeting_<timestamp>_<title>.m4a` → `<title>`.
    static func titleFromFilename(_ filename: String) -> String? {
        guard
            let body = CalendarMatcher.nameAfterPrefix(
                URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent)
        else { return nil }
        let rest = body.dropFirst(Constants.DateFormat.timestamp.count)
        guard rest.hasPrefix("_") else { return nil }
        let title = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    /// Entries containing every word of `query` (case and diacritic insensitive)
    /// in their title, participants, transcript or live text. Empty query: everything.
    static func search(_ entries: [LibraryEntry], query: String) -> [Hit] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else {
            return entries.map { Hit(entry: $0, field: nil, snippet: nil) }
        }
        return entries.compactMap { entry in
            let fields: [(Field, String?)] = [
                (.transcript, entry.transcript), (.live, entry.live),
                (.title, entry.title), (.participants, entry.participants.joined(separator: ", ")),
            ]
            let matchesAll = words.allSatisfy { word in
                fields.contains { $0.1?.localizedStandardContains(word) == true }
            }
            guard matchesAll,
                let (field, text) = fields.first(where: { $0.1?.localizedStandardContains(first) == true }),
                let text
            else { return nil }
            let isText = field == .transcript || field == .live
            return Hit(entry: entry, field: field, snippet: isText ? snippet(of: text, around: first) : nil)
        }
    }

    /// About 120 characters around the first match of `word`, on one line.
    static func snippet(of text: String, around word: String) -> String? {
        guard let range = text.localizedStandardRange(of: word) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 70, limitedBy: text.endIndex) ?? text.endIndex
        let body = text[start..<end].split(whereSeparator: \.isNewline).joined(separator: " ")
        return (start > text.startIndex ? "…" : "") + body + (end < text.endIndex ? "…" : "")
    }
}
