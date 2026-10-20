import AppKit
import SwiftUI

// MARK: - Calendar Tab

struct CalendarSettingsTab: View {
    @Bindable private var settings: SettingsStore
    private let permissionMonitor: PermissionMonitor
    private let calendar: CalendarMonitor

    init(settings: SettingsStore, permissionMonitor: PermissionMonitor, calendar: CalendarMonitor) {
        self.settings = settings
        self.permissionMonitor = permissionMonitor
        self.calendar = calendar
    }

    /// Calendars grouped by account, in the source's order.
    private var accounts: [(name: String, calendars: [CalendarInfo])] {
        var result: [(name: String, calendars: [CalendarInfo])] = []
        for info in calendar.calendars {
            if result.last?.name == info.account {
                result[result.count - 1].calendars.append(info)
            } else {
                result.append((info.account, [info]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "calendar",
                    gradientColors: [.red, .orange],
                    title: L10n.settingsCalendarHeaderTitle,
                    subtitle: L10n.settingsCalendarHeaderSubtitle
                )

                SettingsCard {
                    SettingsPermissionRow(
                        title: L10n.permissionCalendarTitle,
                        description: L10n.permissionCalendarDescription,
                        icon: "calendar",
                        status: permissionMonitor.calendar,
                        request: { await permissionMonitor.requestCalendar() },
                        openSettings: { permissionMonitor.openSystemSettings(for: .calendar) }
                    )
                }

                SettingsCard {
                    SettingRow(
                        icon: "calendar.badge.checkmark",
                        iconColor: .red,
                        title: L10n.settingsCalendarEnabledTitle,
                        subtitle: L10n.settingsCalendarEnabledSubtitle
                    ) {
                        Toggle("", isOn: $settings.calendarEnabled)
                            .toggleStyle(.switch)
                    }

                    Divider()
                        .padding(.leading, 52)

                    SettingRow(
                        icon: "bell.badge.fill",
                        iconColor: .orange,
                        title: L10n.settingsCalendarRemindersTitle,
                        subtitle: L10n.settingsCalendarRemindersSubtitle
                    ) {
                        Toggle("", isOn: $settings.calendarRemindersEnabled)
                            .toggleStyle(.switch)
                    }
                    .disabled(!settings.calendarEnabled)

                    if settings.calendarRemindersEnabled {
                        Divider()
                            .padding(.leading, 52)

                        SettingRow(
                            icon: "clock.fill",
                            iconColor: .orange,
                            title: L10n.settingsCalendarLeadTitle,
                            subtitle: L10n.settingsCalendarLeadMinutes(settings.calendarReminderLeadMinutes)
                        ) {
                            Stepper(
                                "",
                                value: $settings.calendarReminderLeadMinutes,
                                in: 0...30
                            )
                            .labelsHidden()
                        }
                        .disabled(!settings.calendarEnabled)
                    }
                }

                if settings.calendarEnabled, !calendar.calendars.isEmpty {
                    SettingsCard {
                        HStack {
                            Label {
                                Text(L10n.settingsCalendarPickerTitle)
                                    .font(.system(size: 14, weight: .medium))
                            } icon: {
                                Image(systemName: "checklist")
                                    .foregroundColor(.red)
                            }

                            Spacer()

                            Button(
                                calendar.allSelected
                                    ? L10n.settingsCalendarPickerDeselectAll : L10n.settingsCalendarPickerSelectAll
                            ) {
                                calendar.setAllSelected(!calendar.allSelected)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text(L10n.settingsCalendarPickerHelp)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        ForEach(accounts, id: \.name) { account in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(account.name.isEmpty ? L10n.settingsCalendarPickerOtherAccount : account.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                ForEach(account.calendars) { info in
                                    Toggle(
                                        isOn: Binding(
                                            get: { calendar.isSelected(info) },
                                            set: { _ in calendar.toggle(info) }
                                        )
                                    ) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(
                                                    info.color.map {
                                                        Color(red: $0.red, green: $0.green, blue: $0.blue)
                                                    } ?? .gray
                                                )
                                                .frame(width: 10, height: 10)
                                            Text(info.title)
                                                .font(.system(size: 13))
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .background(Color(.windowBackgroundColor))
    }
}
