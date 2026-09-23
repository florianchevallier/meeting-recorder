import Foundation

/// What the calendar tells WhisperX about a recording: how many people may
/// speak, and the words it should expect (title, participant names, glossary).
struct TranscriptionHints: Sendable, Equatable {
    var minSpeakers: Int?
    var maxSpeakers: Int?
    var initialPrompt: String?

    /// Whisper only reads the last ~224 tokens of its prompt.
    static let maxPromptLength = 400

    /// - Parameters:
    ///   - event: The meeting the recording belongs to, if known.
    ///   - glossary: Free-form vocabulary from the settings.
    ///   - maxSpeakers: Upper bound from the settings, used without an event.
    ///   - packTerms: Terms of the selected vocabulary packs; last, so the cut drops them first.
    static func make(
        event: CalendarEvent?, glossary: String, maxSpeakers: Int, packTerms: [String] = []
    ) -> TranscriptionHints {
        // The invitee count is an upper bound, not a head count: some people never speak.
        let upperBound = event?.expectedSpeakerCount ?? maxSpeakers
        let clamped = min(max(upperBound, 1), Constants.Transcription.maxSpeakers)

        var parts: [String] = []
        if let title = event?.title, !title.isEmpty {
            parts.append(title)
        }
        let names = (event?.expectedParticipants ?? []).compactMap(\.name).filter { !$0.isEmpty }
        if !names.isEmpty {
            parts.append(names.joined(separator: ", "))
        }
        if !glossary.isEmpty {
            parts.append(glossary)
        }
        if !packTerms.isEmpty {
            parts.append(packTerms.joined(separator: ", "))
        }
        let prompt = sanitizedPrompt(parts.map { sanitized($0) }.filter { !$0.isEmpty }.joined(separator: ". "))

        return TranscriptionHints(
            minSpeakers: event?.expectedSpeakerCount == nil ? nil : 1,
            maxSpeakers: clamped,
            initialPrompt: prompt.isEmpty ? nil : prompt
        )
    }

    /// Drops control characters and the characters a shell would interpret
    /// (the server no longer uses a shell, but older deployments did), and
    /// collapses whitespace.
    static func sanitized(_ text: String) -> String {
        let forbidden = CharacterSet(charactersIn: "\"`$\\").union(.controlCharacters)
        let cleaned = String(text.unicodeScalars.map { forbidden.contains($0) ? " " : Character($0) })
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Cut at a word boundary under `maxPromptLength`.
    private static func sanitizedPrompt(_ prompt: String) -> String {
        guard prompt.count > maxPromptLength else { return prompt }
        let head = prompt.prefix(maxPromptLength)
        guard let lastSpace = head.lastIndex(of: " ") else { return String(head) }
        return String(head[..<lastSpace])
    }
}
