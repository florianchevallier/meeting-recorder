import Testing
import Foundation
@testable import MeetingRecorder

@Suite("MeetingMetadata")
struct MeetingMetadataTests {
    typealias F = CalendarFixtures

    @Test("Sidecar sits next to the recording and round-trips")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let recording = directory.appendingPathComponent("meeting_2026-09-22_10-00-00_Point hebdo.m4a")
        #expect(
            MeetingMetadata.url(forRecording: recording).lastPathComponent
                == "meeting_2026-09-22_10-00-00_Point hebdo.meeting.json")

        let event = F.event(
            "sync", F.date(10), F.date(11), title: "Point hebdo",
            organizer: F.person("Alice"), attendees: [F.person("Bob", .tentative)],
            meetingURL: URL(string: "https://teams.microsoft.com/l/meetup-join/x"))
        let metadata = MeetingMetadata(recordingStartedAt: F.date(9, 58), event: event)
        try metadata.write(nextTo: recording)

        #expect(try MeetingMetadata.read(forRecording: recording) == metadata)
    }
}
