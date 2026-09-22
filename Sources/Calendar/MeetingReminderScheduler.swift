import os
import Foundation
import Observation
import UserNotifications

/// Schedules "meeting in N min" notifications with a Record action, from the
/// events `CalendarMonitor` publishes. Everything it schedules carries the
/// `meety.reminder.` prefix and is replaced wholesale on every change.
///
/// Inert outside an app bundle: `UNUserNotificationCenter.current()` traps
/// when there is no bundle identifier (`./.build/debug/MeetingRecorder`).
@MainActor
final class MeetingReminderScheduler: NSObject {
    nonisolated static let categoryID = "meety.reminder"
    nonisolated static let recordActionID = "meety.reminder.record"
    nonisolated private static let requestPrefix = "meety.reminder."

    private let calendar: CalendarMonitor
    private let settings: SettingsStore
    private let onRecord: @MainActor () -> Void
    private var task: Task<Void, Never>?

    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    init(calendar: CalendarMonitor, settings: SettingsStore, onRecord: @escaping @MainActor () -> Void) {
        self.calendar = calendar
        self.settings = settings
        self.onRecord = onRecord
    }

    // MARK: Lifecycle

    func start() {
        guard task == nil, let center else { return }
        center.delegate = self
        let record = UNNotificationAction(
            identifier: Self.recordActionID, title: L10n.calendarReminderRecordAction, options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: [record], intentIdentifiers: [])
        ])

        let calendar = self.calendar
        let settings = self.settings
        task = Task { [weak self] in
            for await (events, enabled, lead) in Observations({
                (
                    calendar.events, settings.calendarRemindersEnabled && calendar.isAvailable,
                    settings.calendarReminderLeadMinutes
                )
            }) {
                // Idempotent: prompts once, the first time reminders are on.
                if enabled, await self?.requestAuthorization() != true { continue }
                await self?.reschedule(events: enabled ? events : [], leadMinutes: lead)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.calendar.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Scheduling

    private func reschedule(events: [CalendarEvent], leadMinutes: Int) async {
        guard let center else { return }
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let reminders = MeetingReminderPlanner.plan(
            events: events, now: Date(), lead: TimeInterval(leadMinutes) * 60)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title.isEmpty ? L10n.calendarUntitledEvent : reminder.title
            content.body = L10n.calendarReminderBody(reminder.start.formatted(date: .omitted, time: .shortened))
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let request = UNNotificationRequest(
                identifier: Self.requestPrefix + reminder.eventID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                Log.calendar.error("Scheduling reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.calendar.info("Scheduled \(reminders.count) meeting reminder(s)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MeetingReminderScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.recordActionID else { return }
        await MainActor.run { onRecord() }
    }
}
