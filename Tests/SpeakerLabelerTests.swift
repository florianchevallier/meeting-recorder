import Testing
import Foundation
@testable import MeetingRecorder

@Suite("SpeakerLabeler")
struct SpeakerLabelerTests {
    typealias T = TranscriptFixtures
    typealias F = CalendarFixtures

    /// Florian (SPEAKER_01) speaks 0–10 s and 20–30 s, Alice (SPEAKER_00) 10–20 s.
    private let dialogue = Transcript(segments: [
        T.segment("SPEAKER_01", 0, 10, "bonjour tout le monde on commence"),
        T.segment("SPEAKER_00", 10, 20, "oui alors de mon côté la migration avance"),
        T.segment("SPEAKER_01", 20, 30, "parfait on regarde les chiffres"),
    ])

    private var oneToOne: CalendarEvent {
        F.event("e", F.date(10), F.date(11), organizer: F.person("Florian", me: true), attendees: [F.person("Alice")])
    }

    @Test("The speaker talking into the microphone is me")
    func selfSpeaker() {
        let activity = T.activity(seconds: 30, mine: [0..<10, 20..<30])
        #expect(SpeakerLabeler.selfSpeaker(in: dialogue, activity: activity) == "SPEAKER_01")
    }

    @Test("A 1:1 names both sides: me from the mic, the other from the calendar")
    func oneToOneNames() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: T.activity(seconds: 30, mine: [0..<10, 20..<30]), event: oneToOne,
            manual: [:], selfFallbackName: "Moi")
        #expect(names == ["SPEAKER_01": "Florian", "SPEAKER_00": "Alice"])
    }

    @Test("In a room, everyone is on the mic: nobody is singled out")
    func room() {
        let activity = T.activity(seconds: 30, mine: [0..<30])
        #expect(SpeakerLabeler.selfSpeaker(in: dialogue, activity: activity) == nil)
    }

    @Test("Laptop speakers (echo): the system is loud too, so the mic never dominates")
    func echo() {
        let window = VoiceActivityRecorder.windowSeconds
        let activity = VoiceActivity(
            windowSeconds: window, microphone: Array(repeating: -22, count: 120),
            system: Array(repeating: -18, count: 120))
        #expect(SpeakerLabeler.selfSpeaker(in: dialogue, activity: activity) == nil)
    }

    @Test("Without an event the local user gets the fallback name")
    func fallbackName() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: T.activity(seconds: 30, mine: [0..<10, 20..<30]), event: nil, manual: [:],
            selfFallbackName: "Moi")
        #expect(names == ["SPEAKER_01": "Moi"])
    }

    @Test("Without activity, a 1:1 cannot be resolved (two unknowns, two participants)")
    func noActivity() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: nil, event: oneToOne, manual: [:], selfFallbackName: "Moi")
        #expect(names.isEmpty)
    }

    @Test("Manual names win, and the calendar fills the last gap around them")
    func manualFirst() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: T.activity(seconds: 30, mine: [0..<10, 20..<30]), event: oneToOne,
            manual: ["SPEAKER_01": "Flo", "SPEAKER_00": ""], selfFallbackName: "Moi")
        #expect(names == ["SPEAKER_01": "Flo", "SPEAKER_00": "Alice"])
    }

    @Test("A free-text name does not push the last speaker onto the wrong participant")
    func freeTextName() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: nil, event: oneToOne, manual: ["SPEAKER_00": "Alice B."],
            selfFallbackName: "Moi")
        #expect(names == ["SPEAKER_00": "Alice B."])
    }

    @Test("Picking a participant for one side of a 1:1 names the other side")
    func pickedParticipant() {
        let names = SpeakerLabeler.names(
            for: dialogue, activity: nil, event: oneToOne, manual: ["SPEAKER_00": "Alice"], selfFallbackName: "Moi")
        #expect(names == ["SPEAKER_00": "Alice", "SPEAKER_01": "Florian"])
    }

    @Test("A speaker with only a few words is not considered")
    func minimumSpeech() {
        let transcript = Transcript(segments: [
            T.segment("SPEAKER_00", 0, 1, "oui"),
            T.segment("SPEAKER_01", 1, 20, "une longue intervention sans le micro local"),
        ])
        let activity = T.activity(seconds: 20, mine: [0..<1])
        #expect(SpeakerLabeler.selfSpeaker(in: transcript, activity: activity) == nil)
    }
}
