import Foundation

/// Sidecar written next to a recording (`<name>.meeting.json`) when it belongs
/// to a calendar event: who was expected, for diarization and later tooling.
struct MeetingMetadata: Codable, Sendable, Equatable {
    static let currentVersion = 1

    let version: Int
    let recordingStartedAt: Date
    let event: CalendarEvent

    init(recordingStartedAt: Date, event: CalendarEvent) {
        self.version = Self.currentVersion
        self.recordingStartedAt = recordingStartedAt
        self.event = event
    }

    // MARK: Files

    static func url(forRecording recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension("meeting.json")
    }

    func write(nextTo recordingURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: Self.url(forRecording: recordingURL), options: .atomic)
    }

    static func read(forRecording recordingURL: URL) throws -> MeetingMetadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MeetingMetadata.self, from: Data(contentsOf: url(forRecording: recordingURL)))
    }
}
