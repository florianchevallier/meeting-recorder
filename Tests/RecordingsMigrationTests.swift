import Testing
import Foundation
@testable import MeetingRecorder

@Suite("RecordingsMigration")
struct RecordingsMigrationTests {
    private let fileManager = FileManager.default
    private let now = Date()

    private func scratch() throws -> (source: URL, destination: URL, root: URL) {
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("Documents")
        let destination = root.appendingPathComponent("Recordings")
        try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        return (source, destination, root)
    }

    /// Writes `name` in `directory`, last modified `age` seconds before `now`.
    private func file(_ name: String, in directory: URL, age: TimeInterval = 3600, contents: String = "x") throws {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: url.path)
    }

    private func names(_ directory: URL) -> Set<String> {
        Set((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
    }

    @Test("Moves a recording with all its sidecars, leaves other files alone")
    func movesGroup() throws {
        let (source, destination, root) = try scratch()
        defer { try? fileManager.removeItem(at: root) }
        let group = [
            "meeting_2026-09-22_10-00-00_J. Doe + A. Smith.m4a",
            "meeting_2026-09-22_10-00-00_J. Doe + A. Smith.txt",
            "meeting_2026-09-22_10-00-00_J. Doe + A. Smith.live.md",
            "meeting_2026-09-22_10-00-00_J. Doe + A. Smith.transcription-job.json",
            "meeting_2026-08-01_09-00-00.mov",
        ]
        for name in group { try file(name, in: source) }
        try file("invoice.pdf", in: source)

        RecordingsMigration.migrate(from: source, to: destination, now: now)

        #expect(names(destination) == Set(group))
        #expect(names(source) == ["invoice.pdf"])
    }

    @Test("A group written recently stays put (another instance may be recording)")
    func skipsBusyGroup() throws {
        let (source, destination, root) = try scratch()
        defer { try? fileManager.removeItem(at: root) }
        try file("meeting_2026-10-20_10-00-00_Call.meeting.json", in: source)
        try file("meeting_2026-10-20_10-00-00_Call.partial.m4a", in: source, age: 5)
        try file("meeting_2026-10-19_10-00-00.m4a", in: source)

        RecordingsMigration.migrate(from: source, to: destination, now: now)

        #expect(names(destination) == ["meeting_2026-10-19_10-00-00.m4a"])
        #expect(
            names(source) == [
                "meeting_2026-10-20_10-00-00_Call.meeting.json", "meeting_2026-10-20_10-00-00_Call.partial.m4a",
            ])
    }

    @Test("Never overwrites, and a second run changes nothing")
    func neverOverwrites() throws {
        let (source, destination, root) = try scratch()
        defer { try? fileManager.removeItem(at: root) }
        try file("meeting_2026-09-22_10-00-00.m4a", in: source, contents: "old")
        try file("meeting_2026-09-22_10-00-00.m4a", in: destination, contents: "new")

        RecordingsMigration.migrate(from: source, to: destination, now: now)
        RecordingsMigration.migrate(from: source, to: destination, now: now)

        let kept = destination.appendingPathComponent("meeting_2026-09-22_10-00-00.m4a")
        #expect(try String(contentsOf: kept, encoding: .utf8) == "new")
        #expect(names(source) == ["meeting_2026-09-22_10-00-00.m4a"])
    }

    @Test("Group key strips the sidecar suffix, not dots in the title")
    func groupKey() {
        let key = "meeting_2026-09-22_10-00-00_J. Doe"
        for suffix in [".m4a", ".partial.m4a", ".transcript.json", ".speakers.json", ".txt", ".live.md"] {
            #expect(RecordingsMigration.groupKey(URL(fileURLWithPath: "/d/" + key + suffix)) == key)
        }
    }
}
