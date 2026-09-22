import Foundation

/// What the popover shows at a given instant: today's meetings split into
/// upcoming (including in progress) and past, each past one with its
/// recordings. Pure, so the view can recompute it every minute for free.
struct CalendarAgenda: Equatable, Sendable {
    struct Entry: Equatable, Sendable, Identifiable {
        let event: CalendarEvent
        let recordings: [URL]
        var id: String { event.id }
    }

    /// Soonest first; an in-progress meeting comes first.
    let upcoming: [Entry]
    /// Most recent first.
    let past: [Entry]

    static let empty = CalendarAgenda(upcoming: [], past: [])

    init(upcoming: [Entry], past: [Entry]) {
        self.upcoming = upcoming
        self.past = past
    }

    init(
        events: [CalendarEvent],
        recordings: [URL],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = Constants.Calendar.menuEntriesLimit
    ) {
        let today = events.filter { calendar.isDate($0.start, inSameDayAs: now) || $0.contains(now) }
        func entry(_ event: CalendarEvent) -> Entry {
            Entry(
                event: event,
                recordings: CalendarMatcher.recordings(
                    for: event, among: events, in: recordings, timeZone: calendar.timeZone)
            )
        }
        self.upcoming = today.filter { $0.end > now }
            .sorted { $0.start < $1.start }
            .prefix(limit)
            .map(entry)
        self.past = today.filter { $0.end <= now }
            .sorted { $0.start > $1.start }
            .prefix(limit)
            .map(entry)
    }
}

/// One reminder notification to schedule.
struct MeetingReminder: Equatable, Sendable {
    let eventID: String
    let title: String
    let start: Date
    let fireDate: Date
}

enum MeetingReminderPlanner {
    /// Reminders for events starting within `horizon`, `lead` before their
    /// start; reminders whose fire date already passed are skipped.
    static func plan(
        events: [CalendarEvent],
        now: Date,
        lead: TimeInterval,
        horizon: TimeInterval = Constants.Calendar.reminderHorizon
    ) -> [MeetingReminder] {
        events
            .filter { $0.start > now && $0.start <= now.addingTimeInterval(horizon) }
            .map { MeetingReminder(eventID: $0.id, title: $0.title, start: $0.start, fireDate: $0.start - lead) }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
    }
}
