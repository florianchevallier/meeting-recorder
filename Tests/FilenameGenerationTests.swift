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
        let date = calendar.date(
            from: DateComponents(
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
        let utcDate = Date(timeIntervalSince1970: 1767225600)  // 2026-01-01 00:00:00 UTC

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

    @Test("An event title is sanitized and appended after the timestamp")
    func title() {
        let date = Date(timeIntervalSince1970: 1767225600)
        let utc = TimeZone(secondsFromGMT: 0)!
        func name(_ title: String?) -> String {
            FileSystemUtilities.createTimestampedFilename(
                prefix: "meeting", extension: "m4a", date: date, timeZone: utc, title: title)
        }

        #expect(name(nil) == "meeting_2026-01-01_00-00-00.m4a")
        #expect(name("Point hebdo") == "meeting_2026-01-01_00-00-00_Point hebdo.m4a")
        #expect(name("Q3: Budget / RH?  \n  v2") == "meeting_2026-01-01_00-00-00_Q3 Budget RH v2.m4a")
        #expect(name("  ...  ") == "meeting_2026-01-01_00-00-00.m4a")
        #expect(name("   ") == "meeting_2026-01-01_00-00-00.m4a")

        let long = String(repeating: "a", count: 100)
        #expect(FileSystemUtilities.sanitizedFilenameComponent(long)?.count == 60)
    }
}
