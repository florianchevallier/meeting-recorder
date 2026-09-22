import Testing
import Foundation
@testable import MeetingRecorder

@Suite("CalendarMatcher")
struct CalendarMatcherTests {
    typealias F = CalendarFixtures

    @Test("A recording belongs to an event from 10 min before its start until its end")
    func matchingWindow() {
        let standup = F.event("standup", F.date(10), F.date(10, 30))
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(9, 50), in: [standup]) == standup)
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(10, 29), in: [standup]) == standup)
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(9, 49), in: [standup]) == nil)
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(10, 30), in: [standup]) == nil)
    }

    @Test("Overlapping events: a meeting link wins, then the closest start")
    func overlapPreference() {
        let focus = F.event("focus", F.date(9), F.date(12))
        let review = F.event("review", F.date(10), F.date(11))
        let teams = F.event(
            "teams", F.date(8), F.date(12), meetingURL: URL(string: "https://teams.microsoft.com/l/meetup-join/x"))

        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(10, 2), in: [focus, review])?.id == "review")
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(10, 2), in: [focus, review, teams])?.id == "teams")
        // Back-to-back: starting the next one early picks the next one.
        let next = F.event("next", F.date(11), F.date(11, 30))
        #expect(CalendarMatcher.event(forRecordingStartedAt: F.date(10, 55), in: [review, next])?.id == "next")
    }

    @Test("Recording start date is parsed from the filename, with or without a title")
    func filenameDate() {
        let plain = "meeting_2026-09-22_10-05-30.m4a"
        let titled = "meeting_2026-09-22_10-05-30_Point hebdo.m4a"
        let expected = F.calendar.date(byAdding: .second, value: 30, to: F.date(10, 5))
        #expect(CalendarMatcher.recordingDate(fromFilename: plain, timeZone: F.timeZone) == expected)
        #expect(CalendarMatcher.recordingDate(fromFilename: titled, timeZone: F.timeZone) == expected)
        #expect(CalendarMatcher.recordingDate(fromFilename: "notes.m4a", timeZone: F.timeZone) == nil)
        #expect(CalendarMatcher.recordingDate(fromFilename: "meeting_2026-09.m4a", timeZone: F.timeZone) == nil)
    }

    @Test("Recordings are attributed to the event that would have named them")
    func recordingsForEvent() {
        let review = F.event("review", F.date(10), F.date(11))
        let next = F.event("next", F.date(11), F.date(11, 30))
        let files = [F.recording(10, 2), F.recording(10, 55), F.recording(14, 0)]
        #expect(
            CalendarMatcher.recordings(for: review, among: [review, next], in: files, timeZone: F.timeZone)
                == [files[0]])
        #expect(
            CalendarMatcher.recordings(for: next, among: [review, next], in: files, timeZone: F.timeZone)
                == [files[1]])
    }

    @Test("Meeting links are found in the URL, location or notes; other links are ignored")
    func meetingLinks() {
        let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc"
        #expect(CalendarMatcher.meetingURL(url: URL(string: teams), location: nil, notes: nil)?.absoluteString == teams)
        #expect(
            CalendarMatcher.meetingURL(url: nil, location: "Salle 3", notes: "Rejoindre : \(teams)\nMerci")?
                .absoluteString == teams)
        #expect(
            CalendarMatcher.meetingURL(url: nil, location: "https://us02web.zoom.us/j/123", notes: nil)?.host()
                == "us02web.zoom.us")
        #expect(CalendarMatcher.meetingURL(url: URL(string: "https://example.com"), location: nil, notes: nil) == nil)
        #expect(CalendarMatcher.meetingURL(url: nil, location: nil, notes: "http://teams.microsoft.com/x") == nil)
    }
}

@Suite("CalendarEvent participants")
struct CalendarEventParticipantTests {
    typealias F = CalendarFixtures

    @Test("Organizer + attendees, minus declined, deduplicated by email")
    func expectedParticipants() {
        let event = F.event(
            "sync", F.date(10), F.date(11),
            organizer: F.person("Alice"),
            attendees: [
                F.person("Alice", email: "ALICE@example.com"),
                F.person("Bob", .tentative),
                F.person("Carol", .declined),
                F.person("Me", .accepted, me: true),
            ])
        #expect(event.expectedParticipants.map(\.displayName) == ["Alice", "Bob", "Me"])
        #expect(event.expectedSpeakerCount == 3)
    }

    @Test("No speaker hint when the calendar knows fewer than two people")
    func noHint() {
        #expect(F.event("solo", F.date(10), F.date(11)).expectedSpeakerCount == nil)
        #expect(F.event("solo", F.date(10), F.date(11), organizer: F.person("Me")).expectedSpeakerCount == nil)
    }
}
