import os
import Foundation
import Observation

/// Today's calendar events plus the recordings on disk, kept fresh by events
/// only: calendar database changes, day changes, permission grants, settings
/// toggles, and an explicit `refresh()` when the popover opens. No polling.
@MainActor
@Observable
final class CalendarMonitor {

    /// Events from the start of today to `now + lookahead` (reminders need tomorrow morning).
    private(set) var events: [CalendarEvent] = []
    /// Every event calendar (for the Settings picker), selected or not.
    private(set) var calendars: [CalendarInfo] = []
    /// `meeting_*.m4a` files in the recordings folder (finalized ones only).
    private(set) var recordings: [URL] = []

    @ObservationIgnored private let source: any CalendarEventSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let permissionMonitor: PermissionMonitor
    @ObservationIgnored private let recordingsProvider: @MainActor () -> [URL]
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var dayObserver: (any NSObjectProtocol)?

    init(
        source: any CalendarEventSource,
        settings: SettingsStore,
        permissionMonitor: PermissionMonitor,
        recordingsProvider: @escaping @MainActor () -> [URL] = CalendarMonitor.recordingsInDocuments,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.source = source
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.recordingsProvider = recordingsProvider
        self.now = now
    }

    /// Calendar enabled in Settings and full access granted.
    var isAvailable: Bool {
        settings.calendarEnabled && permissionMonitor.calendar == .granted
    }

    // MARK: Lifecycle

    func start() {
        guard tasks.isEmpty else { return }
        let changes = source.changes()
        tasks.append(
            Task { [weak self] in
                for await _ in changes { self?.refresh() }
            })
        // Covers the grant (the store must be reset first) and the Settings toggle.
        let settings = self.settings
        let permissionMonitor = self.permissionMonitor
        tasks.append(
            Task { [weak self] in
                for await _ in Observations({ (settings.calendarEnabled, permissionMonitor.calendar == .granted) }) {
                    self?.source.reset()
                    self?.refresh()
                }
            })
        tasks.append(
            Task { [weak self] in
                for await _ in Observations({ settings.calendarSelectedIDs }) {
                    self?.refresh()
                }
            })
        dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        if let dayObserver { NotificationCenter.default.removeObserver(dayObserver) }
        dayObserver = nil
    }

    // MARK: Refresh

    func refresh() {
        let fetched: [CalendarEvent]
        let available: [CalendarInfo]
        if isAvailable {
            let date = now()
            let startOfDay = Calendar.current.startOfDay(for: date)
            fetched = source.events(
                from: startOfDay, to: date.addingTimeInterval(Constants.Calendar.lookahead),
                calendarIDs: settings.calendarSelectedIDs)
            available = source.calendars()
        } else {
            fetched = []
            available = []
        }
        let files = recordingsProvider()
        if fetched != events { events = fetched }
        if available != calendars { calendars = available }
        if files != recordings { recordings = files }
        Log.calendar.debug("Calendar refreshed: \(fetched.count) events, \(files.count) recordings")
    }

    // MARK: Selection

    func isSelected(_ calendar: CalendarInfo) -> Bool {
        CalendarSelection.isSelected(calendar.id, in: settings.calendarSelectedIDs)
    }

    func toggle(_ calendar: CalendarInfo) {
        settings.calendarSelectedIDs = CalendarSelection.toggled(
            calendar.id, in: settings.calendarSelectedIDs, all: calendars)
    }

    var allSelected: Bool {
        CalendarSelection.allSelected(in: settings.calendarSelectedIDs, all: calendars)
    }

    /// Checking all goes back to `nil`, so calendars added later are included too.
    func setAllSelected(_ selected: Bool) {
        settings.calendarSelectedIDs = selected ? nil : []
    }

    // MARK: Queries

    /// The event a recording starting at `date` belongs to (refreshes first).
    func currentEvent(at date: Date) -> CalendarEvent? {
        refresh()
        return CalendarMatcher.event(forRecordingStartedAt: date, in: events)
    }

    func agenda(at date: Date) -> CalendarAgenda {
        CalendarAgenda(events: events, recordings: recordings, now: date)
    }

    // MARK: Recordings on disk

    static func recordingsInDocuments() -> [URL] {
        guard let documents = FileSystemUtilities.getDocumentsDirectory(),
            let files = try? FileManager.default.contentsOfDirectory(
                at: documents, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        else { return [] }
        let prefix = Constants.Permissions.recordingPrefix + "_"
        return
            files
            .filter {
                $0.lastPathComponent.hasPrefix(prefix)
                    && $0.pathExtension == Constants.Permissions.recordingExtension
                    && !$0.deletingPathExtension().lastPathComponent.hasSuffix(".partial")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
