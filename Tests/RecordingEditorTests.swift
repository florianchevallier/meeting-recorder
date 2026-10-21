import Testing
import Foundation
@testable import MeetingRecorder

@Suite("RecordingEditor")
struct RecordingEditorTests {
    typealias F = CalendarFixtures
    private let fileManager = FileManager.default

    private func scratch() throws -> URL {
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func touch(_ name: String, in directory: URL) throws {
        try "x".write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func names(_ directory: URL) -> Set<String> {
        Set((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
    }

    @Test("A pre-0.6 `meeting_unified_` name is renamed to the current scheme with its real timestamp")
    func renameLegacyName() {
        let audio = URL(fileURLWithPath: "/R/meeting_unified_2026-09-21_14-00-02.m4a")
        #expect(
            RecordingEditor.renamed(audio, to: "Point")?.lastPathComponent == "meeting_2026-09-21_14-00-02_Point.m4a")
        #expect(RecordingEditor.renamed(URL(fileURLWithPath: "/R/notes.m4a"), to: "Point") == nil)
    }

    @Test("Rename moves every sidecar, keeps the timestamp and retitles the event")
    func rename() throws {
        let directory = try scratch()
        defer { try? fileManager.removeItem(at: directory) }
        let audio = directory.appendingPathComponent("meeting_2026-09-22_10-00-00_Old.m4a")
        for suffix in [".m4a", ".live.md", ".activity.json", ".speakers.json"] {
            try touch("meeting_2026-09-22_10-00-00_Old" + suffix, in: directory)
        }
        try touch("meeting_2026-09-22_10-00-00_Older.m4a", in: directory)
        let event = F.event("e", F.date(10), F.date(11), title: "Old")
        try MeetingMetadata(recordingStartedAt: F.date(10), event: event).write(nextTo: audio)

        let renamed = try RecordingEditor.rename(audio, to: "  Point / hebdo ")

        #expect(renamed.lastPathComponent == "meeting_2026-09-22_10-00-00_Point hebdo.m4a")
        #expect(
            names(directory) == [
                "meeting_2026-09-22_10-00-00_Point hebdo.m4a", "meeting_2026-09-22_10-00-00_Point hebdo.live.md",
                "meeting_2026-09-22_10-00-00_Point hebdo.activity.json",
                "meeting_2026-09-22_10-00-00_Point hebdo.speakers.json",
                "meeting_2026-09-22_10-00-00_Point hebdo.meeting.json", "meeting_2026-09-22_10-00-00_Older.m4a",
            ])
        #expect(try MeetingMetadata.read(forRecording: renamed).event.title == "Point / hebdo")
    }

    @Test("A name clash renames nothing")
    func clash() throws {
        let directory = try scratch()
        defer { try? fileManager.removeItem(at: directory) }
        try touch("meeting_2026-09-22_10-00-00_A.m4a", in: directory)
        try touch("meeting_2026-09-22_10-00-00_A.live.md", in: directory)
        try touch("meeting_2026-09-22_10-00-00_B.live.md", in: directory)
        let before = names(directory)

        #expect(throws: RecordingEditor.EditError.self) {
            try RecordingEditor.rename(directory.appendingPathComponent("meeting_2026-09-22_10-00-00_A.m4a"), to: "B")
        }
        #expect(names(directory) == before)
    }

    @Test("Linking writes the event and renames after it; removing a participant drops organizer and attendee copies")
    func linkAndRemove() throws {
        let directory = try scratch()
        defer { try? fileManager.removeItem(at: directory) }
        try touch("meeting_2026-09-22_10-00-00.m4a", in: directory)
        let alice = F.person("Alice")
        let event = F.event(
            "e", F.date(10), F.date(11), title: "Rétro", organizer: alice, attendees: [alice, F.person("Bob")])

        let linked = try RecordingEditor.link(
            directory.appendingPathComponent("meeting_2026-09-22_10-00-00.m4a"), to: event)
        #expect(linked.lastPathComponent == "meeting_2026-09-22_10-00-00_Rétro.m4a")

        try RecordingEditor.remove(alice, from: linked)
        let saved = try MeetingMetadata.read(forRecording: linked).event
        #expect(saved.expectedParticipants.map(\.displayName) == ["Bob"])
        #expect(saved.title == "Rétro")
    }
}
