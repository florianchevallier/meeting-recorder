import Testing
import Foundation
@testable import MeetingRecorder

@Suite("TranscriptionHints")
struct TranscriptionHintsTests {
    typealias F = CalendarFixtures

    private var event: CalendarEvent {
        F.event(
            "e", F.date(10), F.date(11), title: "Point \"hebdo\" $(id)",
            organizer: F.person("Florian", me: true),
            attendees: [F.person("Alice"), F.person("Bob"), F.person("Chloé", .declined)])
    }

    @Test("The invitees are an upper bound, not a head count")
    func speakerRange() {
        let hints = TranscriptionHints.make(event: event, glossary: "", maxSpeakers: 2)
        #expect(hints.minSpeakers == 1)
        #expect(hints.maxSpeakers == 3)  // Florian, Alice, Bob (Chloé declined)
    }

    @Test("Without an event, the setting is the upper bound and there is no lower bound")
    func noEvent() {
        let hints = TranscriptionHints.make(event: nil, glossary: "", maxSpeakers: 4)
        #expect(hints.minSpeakers == nil)
        #expect(hints.maxSpeakers == 4)
        #expect(hints.initialPrompt == nil)
    }

    @Test("An oversized setting is clamped to what the server accepts")
    func clamp() {
        #expect(TranscriptionHints.make(event: nil, glossary: "", maxSpeakers: 50).maxSpeakers == 20)
    }

    @Test("The prompt carries title, names and glossary, without shell characters")
    func prompt() {
        let prompt = TranscriptionHints.make(event: event, glossary: "WhisperX, Kubernetes", maxSpeakers: 2)
            .initialPrompt
        #expect(prompt == "Point hebdo (id). Florian, Alice, Bob. WhisperX, Kubernetes")
    }

    @Test("The prompt is cut at a word boundary")
    func promptLength() {
        let glossary = Array(repeating: "mot", count: 200).joined(separator: " ")
        let prompt = TranscriptionHints.make(event: nil, glossary: glossary, maxSpeakers: 2).initialPrompt ?? ""
        #expect(prompt.count <= TranscriptionHints.maxPromptLength)
        #expect(prompt.hasSuffix("mot"))
    }

    @Test("Control characters and quotes become spaces, whitespace collapses")
    func sanitize() {
        #expect(TranscriptionHints.sanitized("a\"b`c$d\\e\n\tf  g") == "a b c d e f g")
    }
}
