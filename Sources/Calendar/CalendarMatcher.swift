import Foundation

/// Pure matching between calendar events and recordings. No EventKit, no I/O.
enum CalendarMatcher {

    /// A recording started this long before an event still belongs to it
    /// (people start Meety when the reminder fires).
    static let earlyStartTolerance: TimeInterval = Constants.Calendar.earlyStartTolerance

    // MARK: Event ↔ recording

    /// The event a recording started at `date` belongs to: `date` must fall in
    /// `[start − tolerance, end)`. Among overlapping events, one with a meeting
    /// link wins, then the one whose start is closest to `date`.
    static func event(forRecordingStartedAt date: Date, in events: [CalendarEvent]) -> CalendarEvent? {
        events
            .filter { $0.start.addingTimeInterval(-earlyStartTolerance) <= date && date < $0.end }
            .min { lhs, rhs in
                if (lhs.meetingURL != nil) != (rhs.meetingURL != nil) { return lhs.meetingURL != nil }
                return abs(lhs.start.timeIntervalSince(date)) < abs(rhs.start.timeIntervalSince(date))
            }
    }

    /// Recordings whose start (parsed from the filename) belongs to `event`,
    /// i.e. `event(forRecordingStartedAt:in:)` would pick it among `events`.
    static func recordings(
        for event: CalendarEvent,
        among events: [CalendarEvent],
        in recordings: [URL],
        timeZone: TimeZone = .current
    ) -> [URL] {
        recordings
            .filter { url in
                guard let date = recordingDate(fromFilename: url.lastPathComponent, timeZone: timeZone) else {
                    return false
                }
                return self.event(forRecordingStartedAt: date, in: events)?.id == event.id
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: Filenames

    /// Start date of a recording from its name: `meeting_yyyy-MM-dd_HH-mm-ss[_title].m4a`.
    static func recordingDate(fromFilename filename: String, timeZone: TimeZone = .current) -> Date? {
        let pattern = Constants.DateFormat.timestamp
        guard let body = nameAfterPrefix(filename) else { return nil }
        let stamp = body.prefix(pattern.count)
        guard stamp.count == pattern.count else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter.date(from: String(stamp))
    }

    /// `<timestamp>[_title].m4a` of `meeting_<timestamp>…`; also reads the `meeting_unified_<timestamp>…`
    /// names the app wrote before 0.6, which are still in people's recordings folder.
    static func nameAfterPrefix(_ filename: String) -> Substring? {
        let prefix = Constants.Permissions.recordingPrefix + "_"
        guard filename.hasPrefix(prefix) else { return nil }
        let body = filename.dropFirst(prefix.count)
        return body.hasPrefix("unified_") ? body.dropFirst("unified_".count) : body
    }

    // MARK: Meeting links

    private static let meetingHosts = ["teams.microsoft.com", "teams.live.com", "zoom.us", "meet.google.com"]

    /// First video-meeting link found in the event URL, location or notes.
    static func meetingURL(url: URL?, location: String?, notes: String?) -> URL? {
        if let url, isMeetingLink(url) { return url }
        for text in [location, notes].compactMap(\.self) {
            if let link = firstMeetingLink(in: text) { return link }
        }
        return nil
    }

    private static func isMeetingLink(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased(), url.scheme == "https" else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func firstMeetingLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).lazy.compactMap(\.url).first(where: isMeetingLink)
    }
}
