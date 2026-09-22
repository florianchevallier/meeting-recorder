import Foundation

/// Renders a transcript as readable text: an optional header, then one block
/// per speaker turn (`[mm:ss] Name: text`). Pure.
enum TranscriptRenderer {

    struct Header: Sendable, Equatable {
        let title: String
        /// Already formatted ("22/09/2026 10:00").
        let date: String
        let participants: [String]
    }

    struct Labels: Sendable {
        /// "Participants" line prefix.
        var participants: String
        /// Name of an unidentified speaker, 1-based ("Speaker 2").
        var unknownSpeaker: @Sendable (Int) -> String
    }

    static func render(
        _ transcript: Transcript, names: [String: String], header: Header?, labels: Labels
    ) -> String {
        var lines: [String] = []

        if let header {
            lines.append(header.title)
            lines.append(header.date)
            if !header.participants.isEmpty {
                lines.append("\(labels.participants): \(header.participants.joined(separator: ", "))")
            }
            lines.append("")
        }

        let order = transcript.speakers
        func displayName(_ speaker: String?) -> String {
            guard let speaker else { return labels.unknownSpeaker(order.count + 1) }
            if let name = names[speaker] { return name }
            return labels.unknownSpeaker((order.firstIndex(of: speaker) ?? order.count) + 1)
        }

        for turn in turns(in: transcript) {
            lines.append("[\(timestamp(turn.start))] \(displayName(turn.speaker)): \(turn.text)")
            lines.append("")
        }

        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Turns

    struct Turn: Equatable {
        let speaker: String?
        let start: Double
        let text: String
    }

    /// Consecutive segments of the same speaker merged. A segment WhisperX left
    /// without a speaker (too short to diarize) joins the current turn.
    static func turns(in transcript: Transcript) -> [Turn] {
        var turns: [Turn] = []
        for segment in transcript.segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if let last = turns.last, segment.speaker == nil || segment.speaker == last.speaker {
                turns[turns.count - 1] = Turn(speaker: last.speaker, start: last.start, text: last.text + " " + text)
            } else {
                turns.append(Turn(speaker: segment.speaker, start: segment.start, text: text))
            }
        }
        return turns
    }

    /// `mm:ss`, or `h:mm:ss` from one hour on.
    static func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}
