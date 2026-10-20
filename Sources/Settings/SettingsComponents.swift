import SwiftUI

// MARK: - Shared Components

struct SettingsHeader: View {
    let icon: String
    let gradientColors: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

struct SettingRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder var control: Control

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            control
        }
    }
}

struct SettingsField<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let help: String?
    @ViewBuilder var content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }

            content

            if let help {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsPermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionStatus
    var requestTitle: String = L10n.onboardingButtonAuthorize
    let request: () async -> Void
    let openSettings: () -> Void

    @State private var isRequesting = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(status.swiftUIColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(status.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailingContent
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch status {
        case .granted:
            Label {
                Text(status.displayName)
                    .font(.system(size: 12, weight: .semibold))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(.green)

        case .denied:
            Button(L10n.onboardingButtonOpenPreferences, action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)

        case .notDetermined, .unknownUntilFirstUse:
            Button {
                isRequesting = true
                Task {
                    await request()
                    isRequesting = false
                }
            } label: {
                if isRequesting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(requestTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isRequesting)
        }
    }
}
