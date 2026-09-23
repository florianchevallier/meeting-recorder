import Testing
import Foundation
@testable import MeetingRecorder

@MainActor
@Suite("CalendarMonitor")
struct CalendarMonitorTests {
    typealias F = CalendarFixtures

    @MainActor
    private struct Harness {
        let source = FakeCalendarEventSource()
        let probes = FakeProbes()
        let settings: SettingsStore
        let permissions: PermissionMonitor
        let monitor: CalendarMonitor

        init(granted: Bool, now: Date = F.date(10, 15)) {
            let defaults = UserDefaults(suiteName: "CalendarMonitorTests-\(UUID().uuidString)")!
            probes.calendar = granted ? .granted : .notDetermined
            settings = SettingsStore(defaults: defaults)
            permissions = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: defaults)
            monitor = CalendarMonitor(
                source: source, settings: settings, permissionMonitor: permissions,
                recordingsProvider: { [F.recording(10, 1)] }, now: { now })
        }
    }

    /// Lets the monitor's observation / change loops run.
    private func settle(until condition: @MainActor () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("Nothing is fetched without calendar access; recordings are still listed")
    func noAccess() {
        let harness = Harness(granted: false)
        harness.source.events = [F.event("review", F.date(10), F.date(11))]
        harness.monitor.refresh()
        #expect(harness.monitor.events.isEmpty)
        #expect(harness.source.fetches == 0)
        #expect(harness.monitor.recordings.count == 1)
    }

    @Test("Refresh fetches from the start of today; currentEvent matches the recording start")
    func refreshAndMatch() {
        let harness = Harness(granted: true)
        let review = F.event("review", F.date(10), F.date(11))
        harness.source.events = [F.event("yesterday", F.date(9, day: 21), F.date(10, day: 21)), review]
        #expect(harness.monitor.currentEvent(at: F.date(10, 15)) == review)
        #expect(harness.monitor.events == [review])
    }

    @Test("Disabling the calendar in Settings hides everything")
    func disabled() {
        let harness = Harness(granted: true)
        harness.source.events = [F.event("review", F.date(10), F.date(11))]
        harness.settings.calendarEnabled = false
        #expect(!harness.monitor.isAvailable)
        #expect(harness.monitor.currentEvent(at: F.date(10, 15)) == nil)
    }

    @Test("Database changes and a later grant trigger a refresh (the grant resets the store)")
    func eventDriven() async {
        let harness = Harness(granted: false)
        harness.source.events = [F.event("review", F.date(10), F.date(11))]
        harness.monitor.start()
        defer { harness.monitor.stop() }

        harness.probes.calendar = .granted
        harness.permissions.refresh()
        await settle { !harness.monitor.events.isEmpty }
        #expect(harness.monitor.events.map(\.id) == ["review"])
        #expect(harness.source.resets >= 1)

        harness.source.events.append(F.event("later", F.date(15), F.date(16)))
        harness.source.sendChange()
        await settle { harness.monitor.events.count == 2 }
        #expect(harness.monitor.events.map(\.id) == ["review", "later"])
    }

    @Test("Unchecking a calendar hides its events; the first toggle makes the selection explicit")
    func selection() async {
        let harness = Harness(granted: true)
        let work = CalendarInfo(id: "work", title: "Work", account: "Exchange", color: nil)
        let birthdays = CalendarInfo(id: "birthdays", title: "Birthdays", account: "iCloud", color: nil)
        harness.source.calendarList = [work, birthdays]
        harness.source.events = [
            F.event("review", F.date(10), F.date(11)), F.event("party", F.date(12), F.date(13)),
        ]
        harness.source.eventCalendar = ["review": "work", "party": "birthdays"]
        harness.monitor.start()
        defer { harness.monitor.stop() }
        await settle { harness.monitor.events.count == 2 }
        #expect(harness.monitor.calendars == [work, birthdays])
        #expect(harness.monitor.isSelected(birthdays))

        harness.monitor.toggle(birthdays)
        #expect(harness.settings.calendarSelectedIDs == ["work"])
        await settle { harness.monitor.events.count == 1 }
        #expect(harness.monitor.events.map(\.id) == ["review"])
        #expect(!harness.monitor.isSelected(birthdays))
    }

    @Test("Check all goes back to every calendar, uncheck all to none")
    func selectAll() async {
        let harness = Harness(granted: true)
        harness.source.calendarList = ["work", "birthdays"].map {
            CalendarInfo(id: $0, title: $0, account: "", color: nil)
        }
        harness.monitor.start()
        defer { harness.monitor.stop() }
        await settle { harness.monitor.calendars.count == 2 }
        #expect(harness.monitor.allSelected)

        harness.monitor.setAllSelected(false)
        #expect(harness.settings.calendarSelectedIDs == [])
        #expect(!harness.monitor.allSelected)

        harness.monitor.setAllSelected(true)
        #expect(harness.settings.calendarSelectedIDs == nil)
        #expect(harness.monitor.allSelected)
    }
}

@Suite("CalendarSelection")
struct CalendarSelectionTests {
    let all = ["a", "b", "c"].map { CalendarInfo(id: $0, title: $0, account: "", color: nil) }

    @Test("nil selects everything; toggling starts from all, then flips one id")
    func toggle() {
        #expect(CalendarSelection.isSelected("z", in: nil))
        let first = CalendarSelection.toggled("b", in: nil, all: all)
        #expect(first == ["a", "c"])
        #expect(!CalendarSelection.isSelected("b", in: first))
        #expect(CalendarSelection.toggled("b", in: first, all: all) == ["a", "b", "c"])
        #expect(CalendarSelection.toggled("a", in: ["a"], all: all).isEmpty)
    }

    @Test("All selected only when every known calendar is checked")
    func allSelected() {
        #expect(CalendarSelection.allSelected(in: nil, all: all))
        #expect(CalendarSelection.allSelected(in: ["a", "b", "c", "gone"], all: all))
        #expect(!CalendarSelection.allSelected(in: ["a", "b"], all: all))
        #expect(!CalendarSelection.allSelected(in: [], all: all))
    }
}
