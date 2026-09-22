import Testing
import Foundation
@testable import MeetingRecorder

@Suite("CalendarAgenda")
struct CalendarAgendaTests {
    typealias F = CalendarFixtures

    private func agenda(_ events: [CalendarEvent], recordings: [URL] = [], now: Date, limit: Int = 3)
        -> CalendarAgenda
    {
        CalendarAgenda(events: events, recordings: recordings, now: now, calendar: F.calendar, limit: limit)
    }

    @Test("Upcoming includes the meeting in progress; past is most recent first; other days excluded")
    func split() {
        let early = F.event("early", F.date(8), F.date(8, 30))
        let late = F.event("late", F.date(9), F.date(9, 30))
        let now = F.event("now", F.date(10), F.date(11))
        let later = F.event("later", F.date(15), F.date(16))
        let tomorrow = F.event("tomorrow", F.date(9, day: 23), F.date(10, day: 23))

        let result = agenda([later, tomorrow, early, now, late], now: F.date(10, 15))
        #expect(result.upcoming.map(\.id) == ["now", "later"])
        #expect(result.past.map(\.id) == ["late", "early"])
    }

    @Test("Each list is capped")
    func limit() {
        let events = (8..<16).map { F.event("e\($0)", F.date($0), F.date($0, 30)) }
        let result = agenda(events, now: F.date(12, 45), limit: 2)
        #expect(result.upcoming.map(\.id) == ["e13", "e14"])
        #expect(result.past.map(\.id) == ["e12", "e11"])
    }

    @Test("Past meetings carry their recordings")
    func recordings() {
        let review = F.event("review", F.date(10), F.date(11))
        let file = F.recording(9, 58, title: "review")
        let result = agenda([review], recordings: [file, F.recording(14, 0)], now: F.date(12))
        #expect(result.past.first?.recordings == [file])
    }
}

@Suite("MeetingReminderPlanner")
struct MeetingReminderPlannerTests {
    typealias F = CalendarFixtures

    @Test("Reminders fire `lead` before events starting within the horizon, never in the past")
    func plan() {
        let events = [
            F.event("started", F.date(9), F.date(11)),
            F.event("imminent", F.date(10, 0), F.date(10, 30)),  // fire date 09:59 < now
            F.event("soon", F.date(10, 30), F.date(11)),
            F.event("tomorrow", F.date(9, day: 23), F.date(10, day: 23)),
            F.event("too far", F.date(11, day: 23), F.date(12, day: 23)),
        ]
        let reminders = MeetingReminderPlanner.plan(
            events: events, now: F.date(9, 59, day: 22).addingTimeInterval(30), lead: 60, horizon: 24 * 3600)
        #expect(reminders.map(\.eventID) == ["soon", "tomorrow"])
        #expect(reminders.first?.fireDate == F.date(10, 29))
    }
}
