import Testing
import Foundation
@testable import MeetingRecorder

@Suite("LiveTranscript")
struct LiveTranscriptTests {

    private func update(_ speaker: LiveSpeaker, _ text: String, at start: TimeInterval, final: Bool = false)
        -> LiveTranscriptUpdate
    {
        LiveTranscriptUpdate(speaker: speaker, text: text, start: start, isFinal: final)
    }

    @Test("A volatile result replaces the previous volatile of the same speaker")
    func volatileReplaces() {
        var transcript = LiveTranscript()
        transcript.apply(update(.them, "Il va", at: 1))
        transcript.apply(update(.them, "Il va falloir", at: 1))
        #expect(transcript.segments.map(\.text) == ["Il va falloir"])
        #expect(transcript.segments.allSatisfy { !$0.isFinal })
    }

    @Test("A final result replaces the volatile, the next volatile follows it")
    func finalThenVolatile() {
        var transcript = LiveTranscript()
        transcript.apply(update(.them, "Il va falloir vous", at: 1))
        transcript.apply(update(.them, "Il va falloir vous calmer.", at: 1, final: true))
        transcript.apply(update(.them, "Dans l'idée", at: 4))
        #expect(transcript.segments.map(\.text) == ["Il va falloir vous calmer.", "Dans l'idée"])
        #expect(transcript.segments.map(\.isFinal) == [true, false])
    }

    @Test("Speakers interleave by start time and keep their own volatile")
    func speakersInterleave() {
        var transcript = LiveTranscript()
        transcript.apply(update(.them, "Bonjour à tous", at: 0))
        transcript.apply(update(.me, "Salut", at: 2))
        transcript.apply(update(.them, "Bonjour à tous.", at: 0, final: true))
        #expect(transcript.segments.map(\.speaker) == [.them, .me])
        #expect(transcript.segments.map(\.isFinal) == [true, false])

        // A late final from "me" that started before a newer "them" segment sorts before it.
        transcript.apply(update(.them, "On commence", at: 5))
        transcript.apply(update(.me, "Salut !", at: 2, final: true))
        #expect(transcript.segments.map(\.text) == ["Bonjour à tous.", "Salut !", "On commence"])
    }

    @Test("An empty or blank result only clears the volatile")
    func blankClearsVolatile() {
        var transcript = LiveTranscript()
        transcript.apply(update(.me, "euh", at: 1))
        transcript.apply(update(.me, "  ", at: 1, final: true))
        #expect(transcript.isEmpty)
    }

    @Test("Markdown holds final segments only, with timestamp and speaker")
    func markdown() {
        var transcript = LiveTranscript()
        transcript.apply(update(.them, "Bonjour.", at: 65, final: true))
        transcript.apply(update(.me, "Salut.", at: 3_725, final: true))
        transcript.apply(update(.them, "En cours", at: 3_800))
        let expected = [
            "**[01:05] \(LiveSpeaker.them.label)** — Bonjour.",
            "**[1:02:05] \(LiveSpeaker.me.label)** — Salut.",
        ].joined(separator: "\n\n")
        #expect(transcript.markdown == expected)
    }
}

@Suite("LiveSpeechTranscriber locale")
struct LiveLocaleTests {
    @Test("A bare language code gets the Mac's region, or the language's home region")
    func requestedLocale() {
        let french = Locale(identifier: "fr_FR")
        #expect(LiveSpeechTranscriber.requestedLocale(for: "fr", current: french).identifier == "fr_FR")
        #expect(
            LiveSpeechTranscriber.requestedLocale(for: "fr", current: Locale(identifier: "fr_BE")).identifier == "fr_BE"
        )
        #expect(
            LiveSpeechTranscriber.requestedLocale(for: "fr", current: Locale(identifier: "en_CA")).identifier == "fr_FR"
        )
        #expect(LiveSpeechTranscriber.requestedLocale(for: "en", current: french).identifier == "en_US")
    }
}

@Suite("LiveTranscript clipboard")
struct LiveTranscriptClipboardTests {
    @Test("Copying the last N minutes keeps the segments that started in that window")
    func lastMinutes() {
        var transcript = LiveTranscript()
        for (start, text) in [(10.0, "début"), (390.0, "milieu"), (650.0, "presque"), (700.0, "fin")] {
            transcript.apply(LiveTranscriptUpdate(speaker: .them, text: text, start: start, isFinal: true))
        }
        let them = LiveSpeaker.them.label
        #expect(transcript.plainText(lastMinutes: 5) == "[10:50] \(them) : presque\n[11:40] \(them) : fin")
        #expect(transcript.plainText(lastMinutes: 10).components(separatedBy: "\n").count == 3)
        #expect(transcript.plainText().components(separatedBy: "\n").count == 4)
        #expect(LiveTranscript().plainText(lastMinutes: 5).isEmpty)
    }
}
