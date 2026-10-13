import os
import AppKit
import Observation

/// Opens the meeting link of the next calendar event in the default browser
/// when it starts (Settings → General → Join meetings automatically).
/// One timer for the next event, rebuilt whenever the events or the setting change.
@MainActor
final class MeetingAutoJoiner {
    private let calendar: CalendarMonitor
    private let settings: SettingsStore
    private var task: Task<Void, Never>?
    private var pending: Task<Void, Never>?

    init(calendar: CalendarMonitor, settings: SettingsStore) {
        self.calendar = calendar
        self.settings = settings
    }

    func start() {
        guard task == nil else { return }
        let calendar = self.calendar
        let settings = self.settings
        task = Task { [weak self] in
            for await (events, enabled) in Observations({
                (calendar.events, settings.autoJoinMeetings && calendar.isAvailable)
            }) {
                self?.schedule(enabled ? events : [])
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        pending?.cancel()
        pending = nil
    }

    private func schedule(_ events: [CalendarEvent]) {
        pending?.cancel()
        pending = nil
        guard let event = MeetingAutoJoinPlanner.next(in: events, now: Date()), let url = event.meetingURL else {
            return
        }
        pending = Task { [weak self] in
            // Continuous clock: after a sleep of the Mac this fires late, hence the end check.
            try? await Task.sleep(for: .seconds(event.start.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            if Date() < event.end {
                Log.calendar.info("Auto-joining meeting \(event.title, privacy: .private)")
                NSWorkspace.shared.open(url)
            }
            self?.schedule(events)
        }
    }
}

enum MeetingAutoJoinPlanner {
    /// The first event with a meeting link that hasn't started yet (one already
    /// in progress at launch is left alone).
    static func next(in events: [CalendarEvent], now: Date) -> CalendarEvent? {
        events
            .filter { $0.meetingURL != nil && $0.start > now }
            .min { $0.start < $1.start }
    }
}
