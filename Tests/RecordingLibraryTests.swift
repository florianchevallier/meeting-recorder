import Testing
import Foundation
@testable import MeetingRecorder

@Suite("RecordingLibrary")
struct RecordingLibraryTests {
    typealias F = CalendarFixtures

    private func entry(
        _ name: String, title: String? = nil, participants: [String] = [], transcript: String? = nil,
        live: String? = nil
    ) -> LibraryEntry {
        let event = F.event("e", F.date(10), F.date(11), attendees: participants.map { F.person($0) })
        return LibraryEntry(
            audio: URL(fileURLWithPath: "/R/" + name), date: nil, title: title, event: event,
            transcript: transcript, live: live)
    }

    @Test("Title from the filename, nil when untitled")
    func titleFromFilename() {
        #expect(RecordingLibrary.titleFromFilename("meeting_2026-09-22_10-00-00_Point hebdo.m4a") == "Point hebdo")
        #expect(RecordingLibrary.titleFromFilename("meeting_2026-09-22_10-00-00_J. Doe.m4a") == "J. Doe")
        #expect(RecordingLibrary.titleFromFilename("meeting_2026-09-22_10-00-00.m4a") == nil)
        #expect(RecordingLibrary.titleFromFilename("notes.m4a") == nil)
    }

    @Test("Load: event title beats filename, sidecar texts read, newest first")
    func load() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let older = directory.appendingPathComponent("meeting_2026-09-22_10-00-00_Old name.m4a")
        let newer = directory.appendingPathComponent("meeting_2026-09-23_10-00-00.m4a")
        let event = F.event("e", F.date(10), F.date(11), title: "Point hebdo", attendees: [F.person("Bob")])
        try MeetingMetadata(recordingStartedAt: F.date(10), event: event).write(nextTo: older)
        try "Bonjour".write(to: RecordingFiles(audio: older).transcriptText, atomically: true, encoding: .utf8)
        try "Salut".write(to: RecordingFiles(audio: newer).liveTranscript, atomically: true, encoding: .utf8)

        let entries = RecordingLibrary.load([older, newer])

        #expect(entries.map(\.audio) == [newer, older])
        #expect(entries[0].title == nil && entries[0].live == "Salut" && entries[0].transcript == nil)
        #expect(entries[1].title == "Point hebdo" && entries[1].participants.contains("Bob"))
        #expect(entries[1].transcript == "Bonjour" && entries[1].date != nil)
    }

    @Test("Every word must match somewhere, ignoring case and accents")
    func search() {
        let entries = [
            entry("a.m4a", title: "Point hebdo", transcript: "On parle du budget de l'équipe."),
            entry("b.m4a", title: "Rétro", participants: ["Alice Martin"], live: "Le déploiement a échoué"),
        ]
        #expect(RecordingLibrary.search(entries, query: "").count == 2)
        #expect(
            RecordingLibrary.search(entries, query: "EQUIPE budget").map(\.entry.audio.lastPathComponent) == ["a.m4a"])
        #expect(RecordingLibrary.search(entries, query: "retro alice").map(\.field) == [.title])
        #expect(RecordingLibrary.search(entries, query: "deploiement").map(\.field) == [.live])
        #expect(RecordingLibrary.search(entries, query: "budget alice").isEmpty)
    }

    @Test("Snippet surrounds the match on one line")
    func snippet() {
        let text = String(repeating: "a ", count: 60) + "budget\nvoté" + String(repeating: " b", count: 60)
        let snippet = RecordingLibrary.snippet(of: text, around: "BUDGET")
        #expect(snippet?.hasPrefix("…") == true && snippet?.hasSuffix("…") == true)
        #expect(snippet?.contains("budget voté") == true)
        #expect(RecordingLibrary.snippet(of: "court budget", around: "budget") == "court budget")
    }
}
