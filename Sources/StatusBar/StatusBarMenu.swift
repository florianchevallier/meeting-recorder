import os
import SwiftUI

/// Status bar popover menu. Reads `RecordingCoordinator` (@Observable) and
/// `PermissionMonitor`; transcription state flows through
/// `coordinator.transcription.state` (@Observable struct).
///
/// Structure notes: nothing ticks while idle — only the duration/ring subtree
/// is wrapped in a `TimelineView`, and only while recording.
struct StatusBarMenu: View {
    let coordinator: RecordingCoordinator
    let permissionMonitor: PermissionMonitor
    let calendar: CalendarMonitor
    let settings: SettingsStore
    let onOpenSettings: () -> Void
    let onEditSpeakers: (URL) -> Void
    let onOpenLiveTranscript: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            mainControlSection
            errorSection
            transcriptionSection
            CalendarMenuSection(
                calendar: calendar,
                permissionMonitor: permissionMonitor,
                settings: settings,
                transcription: coordinator.transcription,
                onEditSpeakers: onEditSpeakers
            )
            quickActionsSection
        }
        .frame(width: Constants.UI.menuWidth)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(MenuStyle.brandGradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.appName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(L10n.appSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusIndicator
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Status Indicator

    private var activity: MenuActivity {
        MenuActivity(
            isStopping: coordinator.isStopping,
            isRecording: coordinator.isRecording,
            isTeamsMeetingDetected: coordinator.isTeamsMeetingDetected
        )
    }

    private var statusIndicator: some View {
        let activity = self.activity
        return HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(activity.gradient)
                .symbolEffect(.pulse, options: .repeating, isActive: activity != .idle)

            Text(activity.shortLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(activity.tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(activity.tint.opacity(activity == .idle ? 0.08 : 0.14), in: .capsule)
        .animation(.smooth, value: activity)
    }

    // MARK: - Main Control Section

    private var mainControlSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if let startedAt = coordinator.recordingStartedAt {
                    ProgressRing(startedAt: startedAt)
                }

                if coordinator.isStopping {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.2)
                } else {
                    RecordButton(isRecording: coordinator.isRecording, action: toggleRecording)
                }
            }

            recordingInfoSection
        }
        .padding(.vertical, 20)
    }

    // MARK: - Recording Info Section

    @ViewBuilder
    private var recordingInfoSection: some View {
        VStack(spacing: 8) {
            if let startedAt = coordinator.recordingStartedAt {
                VStack(spacing: 4) {
                    DurationLabel(startedAt: startedAt)

                    Text(coordinator.state.isRecovering ? L10n.statusReconnecting : L10n.statusRecording)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            } else if coordinator.isStopping {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.statusFinishing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if coordinator.isStarting {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(
                        permissionMonitor.systemAudio == .unknownUntilFirstUse
                            ? L10n.statusWaitingSystemAudio : L10n.statusStarting
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 4) {
                    Text(coordinator.isTeamsMeetingDetected ? L10n.statusTeamsDetected : L10n.statusReady)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(coordinator.isTeamsMeetingDetected ? Color.blue : Color.primary)

                    if coordinator.isTeamsMeetingDetected {
                        Label(L10n.statusTeamsActive, systemImage: "video.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.blue)
                    } else {
                        HStack(spacing: 12) {
                            Label(L10n.audioMicrophone, systemImage: "mic.fill")
                            Label(L10n.audioSystem, systemImage: "speaker.wave.2.fill")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: coordinator.isRecording)
    }

    // MARK: - Transcription Section

    @ViewBuilder
    private var transcriptionSection: some View {
        if coordinator.transcription.state.isTranscribing {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "waveform.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.purple)
                            .symbolEffect(.pulse, options: .repeating)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionRunning)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(coordinator.transcription.state.progress)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let percent = coordinator.transcription.state.percent {
                            ProgressView(value: Double(percent), total: 100)
                                .controlSize(.small)
                                .tint(.purple)
                        }

                        if !coordinator.transcription.queue.isEmpty {
                            Text(L10n.menuTranscriptionQueued(coordinator.transcription.queue.count))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if coordinator.transcription.state.status == .running,
                        coordinator.transcription.state.percent == nil
                    {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }

                    if coordinator.transcription.current != nil {
                        Button(L10n.menuTranscriptionCancel) { coordinator.transcription.cancel() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.05))
            }
        } else if let error = coordinator.transcription.state.error {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(error)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if coordinator.transcription.lastFailed != nil {
                        Button(L10n.menuTranscriptionRetry) { coordinator.transcription.retry() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.05))
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 20)

            HStack(spacing: 0) {
                QuickActionButton(icon: "folder.fill", title: L10n.actionFolder, action: openRecordingsFolder)

                Divider()
                    .frame(height: Constants.UI.quickActionHeight)

                QuickActionButton(
                    icon: "captions.bubble.fill", title: L10n.actionLiveTranscript, action: onOpenLiveTranscript)

                Divider()
                    .frame(height: Constants.UI.quickActionHeight)

                QuickActionButton(icon: "gearshape.fill", title: L10n.actionSettings, action: onOpenSettings)
            }
            .frame(height: Constants.UI.quickActionHeight)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Error Message

    @ViewBuilder
    private var errorSection: some View {
        if let error = coordinator.error {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)

                        Text(error.message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        Spacer()
                    }

                    if let remedy = error.remedy {
                        Button {
                            perform(remedy)
                        } label: {
                            Label(remedy.title, systemImage: remedy.symbolName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
            }
        }
    }

    // MARK: - Helpers

    private func toggleRecording() {
        guard !coordinator.isStopping else { return }
        if coordinator.isRecording {
            coordinator.stop()
        } else {
            coordinator.start()
        }
    }

    private func perform(_ remedy: RecordingError.Remedy) {
        switch remedy {
        case .openPrivacySettings(let kind):
            permissionMonitor.openSystemSettings(for: kind)
        case .openFolder(let url):
            NSWorkspace.shared.open(url)
        }
    }

    private func openRecordingsFolder() {
        guard let documentsURL = FileSystemUtilities.getDocumentsDirectory() else {
            Log.ui.error("Unable to open Documents directory")
            return
        }
        NSWorkspace.shared.open(documentsURL)
    }
}

// MARK: - Activity

/// Collapses the coordinator's flags into one value for the indicator.
private enum MenuActivity: Equatable {
    case idle, teams, recording, finishing

    init(isStopping: Bool, isRecording: Bool, isTeamsMeetingDetected: Bool) {
        if isStopping {
            self = .finishing
        } else if isRecording {
            self = .recording
        } else if isTeamsMeetingDetected {
            self = .teams
        } else {
            self = .idle
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .finishing: return MenuStyle.finishingGradient
        case .recording: return MenuStyle.recordingGradient
        case .teams: return MenuStyle.teamsGradient
        case .idle: return MenuStyle.idleGradient
        }
    }

    var tint: Color {
        switch self {
        case .finishing: return .orange
        case .recording: return .red
        case .teams: return .blue
        case .idle: return .secondary
        }
    }

    var shortLabel: String {
        switch self {
        case .finishing: return L10n.statusFinishingShort
        case .recording: return L10n.statusRecordingShort
        case .teams: return L10n.statusTeamsShort
        case .idle: return L10n.statusIdle
        }
    }
}

// MARK: - Style

private enum MenuStyle {
    static let brandGradient = LinearGradient(
        colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let finishingGradient = LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
    static let recordingGradient = LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
    static let teamsGradient = LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
    static let idleGradient = LinearGradient(
        colors: [.gray.opacity(0.3), .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    static let ringGradient = LinearGradient(
        colors: [.red, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Ticking subviews (only exist while recording)

private struct ProgressRing: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1.0)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            Circle()
                .trim(from: 0, to: min(elapsed / Constants.UI.maxRecordingDurationForProgress, 1.0))
                .stroke(
                    MenuStyle.ringGradient,
                    style: StrokeStyle(lineWidth: Constants.UI.progressRingLineWidth, lineCap: .round)
                )
                .frame(width: Constants.UI.controlCircleSize, height: Constants.UI.controlCircleSize)
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct DurationLabel: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1.0)) { context in
            Text(Self.format(context.date.timeIntervalSince(startedAt)))
                .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(context.date.timeIntervalSince(startedAt)))
        }
    }

    static func format(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Record Button

private struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        // The primary action, always in color. Tinted glass (`.glassProminent`, `.glassEffect(.tint)`)
        // renders grey in the menu bar popover, so this is a filled disc with a glass-like rim.
        let tint: Color = isRecording ? .red : .blue
        Button(action: action) {
            Image(systemName: isRecording ? "stop.fill" : "record.circle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Constants.UI.controlButtonSize, height: Constants.UI.controlButtonSize)
                .background(tint.gradient, in: .circle)
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.35), radius: isHovering ? 12 : 8, y: 3)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.smooth, value: isRecording)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHovering ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
            .animation(.smooth(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
