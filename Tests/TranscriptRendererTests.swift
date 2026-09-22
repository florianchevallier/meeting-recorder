import Testing
import Foundation
@testable import MeetingRecorder

@Suite("TranscriptRenderer")
struct TranscriptRendererTests {
    typealias T = TranscriptFixtures

    private let labels = TranscriptRenderer.Labels(
        participants: "Participants", unknownSpeaker: { "Intervenant \($0)" })

    @Test("Header, then one block per turn with named and unnamed speakers")
    func render() {
        let transcript = Transcript(segments: [
            T.segment("SPEAKER_01", 1.5, 4, "Bonjour à tous."),
            T.segment("SPEAKER_01", 4, 6, "On commence ?"),
            T.segment(nil, 6, 6.5, "Hum."),
            T.segment("SPEAKER_00", 65, 70, "Oui, allons-y."),
        ])
        let text = TranscriptRenderer.render(
            transcript, names: ["SPEAKER_01": "Florian"],
            header: .init(title: "Point hebdo", date: "22 septembre 2026 à 10:00", participants: ["Florian", "Alice"]),
            labels: labels)

        #expect(
            text == """
                Point hebdo
                22 septembre 2026 à 10:00
                Participants: Florian, Alice

                [00:01] Florian: Bonjour à tous. On commence ? Hum.

                [01:05] Intervenant 2: Oui, allons-y.

                """)
    }

    @Test("Without a header the text starts with the first turn")
    func noHeader() {
        let text = TranscriptRenderer.render(
            Transcript(segments: [T.segment("SPEAKER_00", 0, 1, "Test")]), names: [:], header: nil, labels: labels)
        #expect(text == "[00:00] Intervenant 1: Test\n")
    }

    @Test("Timestamps switch to h:mm:ss after an hour")
    func timestamps() {
        #expect(TranscriptRenderer.timestamp(59.9) == "00:59")
        #expect(TranscriptRenderer.timestamp(3_725) == "1:02:05")
        #expect(TranscriptRenderer.timestamp(-3) == "00:00")
    }
}
