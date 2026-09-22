import Foundation
@testable import MeetingRecorder

/// Builders for calendar tests (Europe/Paris, fixed dates).
enum CalendarFixtures {
    static let timeZone = TimeZone(identifier: "Europe/Paris")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// 2026-09-22 at `hour:minute` Paris time.
    static func date(_ hour: Int, _ minute: Int = 0, day: Int = 22) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    static func person(
        _ name: String, _ status: Participant.Status = .accepted, email: String? = nil, me: Bool = false
    ) -> Participant {
        Participant(
            name: name, email: email ?? "\(name.lowercased())@example.com", status: status, isCurrentUser: me)
    }

    static func event(
        _ id: String,
        _ start: Date,
        _ end: Date,
        title: String? = nil,
        organizer: Participant? = nil,
        attendees: [Participant] = [],
        meetingURL: URL? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title ?? id, start: start, end: end,
            organizer: organizer, attendees: attendees, meetingURL: meetingURL)
    }

    static func recording(_ hour: Int, _ minute: Int, second: Int = 0, title: String? = nil) -> URL {
        let name = FileSystemUtilities.createTimestampedFilename(
            prefix: "meeting", extension: "m4a",
            date: calendar.date(byAdding: .second, value: second, to: date(hour, minute))!,
            timeZone: timeZone, title: title)
        return URL(fileURLWithPath: "/tmp/\(name)")
    }
}
