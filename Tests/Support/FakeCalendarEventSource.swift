import Foundation
@testable import MeetingRecorder

/// Scriptable `CalendarEventSource` for `CalendarMonitor` tests.
@MainActor
final class FakeCalendarEventSource: CalendarEventSource {
    var events: [CalendarEvent] = []
    var calendarList: [CalendarInfo] = []
    /// Event id → calendar id, for selection filtering.
    var eventCalendar: [String: String] = [:]
    private(set) var fetches = 0
    private(set) var resets = 0
    private var continuation: AsyncStream<Void>.Continuation?

    func calendars() -> [CalendarInfo] { calendarList }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>?) -> [CalendarEvent] {
        fetches += 1
        return events.filter { event in
            event.end > start && event.start < end
                && (calendarIDs.map { $0.contains(eventCalendar[event.id] ?? "") } ?? true)
        }
    }

    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation
        return stream
    }

    func reset() { resets += 1 }

    func sendChange() { continuation?.yield() }
}
