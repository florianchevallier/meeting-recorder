import os
import Foundation
import AppKit
import EventKit

/// Read-only access to calendar events. Authorization is owned by
/// `PermissionMonitor`; the live implementation wraps one `EKEventStore`,
/// tests drive a fake.
@MainActor
protocol CalendarEventSource: AnyObject {
    /// Event calendars, sorted by account then title. Empty without access.
    func calendars() -> [CalendarInfo]
    /// Non-all-day events overlapping `[start, end)` in the given calendars
    /// (`nil` = all). Empty without access.
    func events(from start: Date, to end: Date, calendarIDs: Set<String>?) -> [CalendarEvent]
    /// Fires whenever the calendar database changes (sync, edit, new account).
    func changes() -> AsyncStream<Void>
    /// Drops cached state; required once access is granted to a store created before.
    func reset()
}

@MainActor
final class EventKitCalendarSource: CalendarEventSource {
    private let store = EKEventStore()

    private var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func calendars() -> [CalendarInfo] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event)
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    account: calendar.source?.title ?? "",
                    color: NSColor(cgColor: calendar.cgColor)?.usingColorSpace(.sRGB).map {
                        CalendarInfo.RGB(
                            red: Double($0.redComponent), green: Double($0.greenComponent),
                            blue: Double($0.blueComponent))
                    }
                )
            }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
    }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>?) -> [CalendarEvent] {
        guard hasAccess else { return [] }
        // `calendars: nil` means all; an empty selection must mean none.
        let calendars = calendarIDs.map { ids in
            store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        }
        if let calendars, calendars.isEmpty { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .map(Self.makeEvent)
    }

    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // Any store in the process: Meety only keeps this one alive.
        let task = Task {
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                continuation.yield()
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func reset() {
        store.reset()
    }

    // MARK: Conversion

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let start: Date = event.startDate
        let attendees = (event.attendees ?? [])
            .filter { $0.participantType == .person || $0.participantType == .unknown }
            .map(makeParticipant)
        return CalendarEvent(
            id: "\(event.calendarItemIdentifier)@\(Int(start.timeIntervalSince1970))",
            title: event.title ?? "",
            start: start,
            end: event.endDate,
            organizer: event.organizer.map(makeParticipant),
            attendees: attendees,
            meetingURL: CalendarMatcher.meetingURL(url: event.url, location: event.location, notes: event.notes)
        )
    }

    private static func makeParticipant(_ participant: EKParticipant) -> Participant {
        let email: String? =
            participant.url.scheme?.lowercased() == "mailto"
            ? participant.url.absoluteString.dropFirst("mailto:".count).removingPercentEncoding
            : nil
        return Participant(
            name: participant.name?.isEmpty == false ? participant.name : nil,
            email: email,
            status: status(participant.participantStatus),
            isCurrentUser: participant.isCurrentUser
        )
    }

    private static func status(_ status: EKParticipantStatus) -> Participant.Status {
        switch status {
        case .accepted, .completed, .delegated: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending, .inProcess: return .pending
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}
