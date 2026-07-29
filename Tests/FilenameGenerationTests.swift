import Testing
import Foundation
@testable import MeetingRecorder

@Suite("Filename generation")
struct FilenameGenerationTests {

    @Test("Filename follows prefix_YYYY-MM-DD_HH-mm-ss.extension format")
    func format() {
        // 2026-07-29 14:30:45 at a fixed timezone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let date = calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 29, hour: 14, minute: 30, second: 45
        ))!

        let filename = FileSystemUtilities.createTimestampedFilename(
            prefix: "meeting_unified",
            extension: "mov",
            date: date,
            timeZone: TimeZone(identifier: "Europe/Paris")!
        )

        #expect(filename == "meeting_unified_2026-07-29_14-30-45.mov")
    }

    @Test("Timestamp uses the injected timezone (not UTC)")
    func localTimezone() {
        // Midnight UTC on Jan 1st = 01:00 in Paris (UTC+1)
        let utcDate = Date(timeIntervalSince1970: 1767225600) // 2026-01-01 00:00:00 UTC

        let paris = FileSystemUtilities.createTimestampedFilename(
            prefix: "meeting",
            extension: "m4a",
            date: utcDate,
            timeZone: TimeZone(identifier: "Europe/Paris")!
        )
        let utc = FileSystemUtilities.createTimestampedFilename(
            prefix: "meeting",
            extension: "m4a",
            date: utcDate,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(paris == "meeting_2026-01-01_01-00-00.m4a")
        #expect(utc == "meeting_2026-01-01_00-00-00.m4a")
        #expect(paris != utc)
    }
}
