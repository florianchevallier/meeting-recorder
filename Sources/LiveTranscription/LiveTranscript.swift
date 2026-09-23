import Foundation

/// Who is speaking: the microphone is "me", the system tap is everyone else.
enum LiveSpeaker: String, CaseIterable, Sendable {
    case me
    case them

    var label: String {
        switch self {
        case .me: return L10n.liveSpeakerMe
        case .them: return L10n.liveSpeakerThem
        }
    }
}

/// One result from a speech transcriber, in recording time (seconds).
struct LiveTranscriptUpdate: Equatable, Sendable {
    let speaker: LiveSpeaker
    let text: String
    let start: TimeInterval
    let isFinal: Bool
}

/// The live transcript as shown in the panel. Pure and testable.
///
/// Apple's `SpeechTranscriber` sends volatile results (the current guess for the
/// utterance in progress, each one replacing the previous) and then one final
/// result for that stretch of audio. So each speaker has at most one volatile
/// segment, and a final result replaces it.
struct LiveTranscript: Equatable, Sendable {

    struct Segment: Identifiable, Equatable, Sendable {
        let id: Int
        let speaker: LiveSpeaker
        let start: TimeInterval
        var text: String
        var isFinal: Bool
    }

    /// Chronological by start time; volatile segments included.
    private(set) var segments: [Segment] = []
    private var nextID = 0

    var isEmpty: Bool { segments.isEmpty }

    mutating func apply(_ update: LiveTranscriptUpdate) {
        let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        segments.removeAll { $0.speaker == update.speaker && !$0.isFinal }
        guard !text.isEmpty else { return }
        let segment = Segment(
            id: nextID, speaker: update.speaker, start: update.start, text: text, isFinal: update.isFinal)
        nextID += 1
        let index = segments.lastIndex { $0.start <= update.start }.map { $0 + 1 } ?? 0
        segments.insert(segment, at: index)
    }

    /// Markdown for one segment, e.g. `**[01:05] Moi** — Bonjour à tous.`
    static func markdownLine(for segment: Segment) -> String {
        "**[\(timestamp(segment.start))] \(segment.speaker.label)** — \(segment.text)"
    }

    /// Final segments only, one paragraph each (what the `.live.md` file holds).
    var markdown: String {
        segments.filter(\.isFinal).map(Self.markdownLine).joined(separator: "\n\n")
    }

    static func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}
