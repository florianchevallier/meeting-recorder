import Foundation

// MARK: - Participant

/// A human attendee of a calendar event (rooms and resources are dropped at
/// conversion time). Persisted in the `.meeting.json` sidecar.
struct Participant: Codable, Sendable, Equatable {
    enum Status: String, Codable, Sendable {
        case accepted
        case declined
        case tentative
        case pending
        case unknown
    }

    let name: String?
    let email: String?
    let status: Status
    /// True for the owner of the calendar the event was read from (the Meety user).
    let isCurrentUser: Bool

    /// Name, then email, then a placeholder: what the UI and diarization show.
    var displayName: String {
        name ?? email ?? "?"
    }
}

// MARK: - Calendar Event

/// Snapshot of one calendar occurrence, decoupled from EventKit so the logic
/// around it stays pure and testable. All-day events never become one.
struct CalendarEvent: Codable, Sendable, Equatable, Identifiable {
    /// `calendarItemIdentifier` + start: each occurrence of a recurring meeting is distinct.
    let id: String
    let title: String
    let start: Date
    let end: Date
    let organizer: Participant?
    let attendees: [Participant]
    let meetingURL: URL?

    /// Everyone expected in the room: attendees plus the organizer, without the
    /// people who declined, deduplicated by email.
    var expectedParticipants: [Participant] {
        var seen = Set<String>()
        var result: [Participant] = []
        for participant in [organizer].compactMap(\.self) + attendees where participant.status != .declined {
            let key = participant.email?.lowercased() ?? participant.displayName
            if seen.insert(key).inserted { result.append(participant) }
        }
        return result
    }

    /// Speaker count hint for diarization; nil when the calendar knows nobody
    /// but the user (a solo block, or an event without invitees).
    var expectedSpeakerCount: Int? {
        let count = expectedParticipants.count
        return count >= 2 ? count : nil
    }

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

// MARK: - Calendar Info

/// One calendar the user can include or exclude (Settings → Calendar).
struct CalendarInfo: Sendable, Equatable, Identifiable {
    struct RGB: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// `EKCalendar.calendarIdentifier`.
    let id: String
    let title: String
    /// Account the calendar belongs to ("iCloud", "Exchange", an email…).
    let account: String
    let color: RGB?
}

/// Which calendars feed Meety. `nil` = every calendar (the default, new ones included);
/// the first toggle turns it into an explicit list, so calendars added later stay out.
enum CalendarSelection {
    static func isSelected(_ id: String, in selection: Set<String>?) -> Bool {
        selection?.contains(id) ?? true
    }

    static func toggled(_ id: String, in selection: Set<String>?, all: [CalendarInfo]) -> Set<String> {
        var result = selection ?? Set(all.map(\.id))
        if result.contains(id) { result.remove(id) } else { result.insert(id) }
        return result
    }
}
