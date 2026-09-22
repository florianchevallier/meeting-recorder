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
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            mainControlSection
            errorSection
            transcriptionSection
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
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Main Control Section

    private var mainControlSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separatorColor), lineWidth: 1)
                    .frame(width: Constants.UI.controlCircleSize, height: Constants.UI.controlCircleSize)

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
                    }

                    Spacer()

                    if coordinator.transcription.state.status == .running {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
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

                QuickActionButton(icon: "gearshape.fill", title: L10n.actionSettings, action: onOpenSettings)
            }
            .frame(height: Constants.UI.quickActionHeight)
        }
        .background(Color(.controlBackgroundColor).opacity(0.3))
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
    static let recordButtonGradient = LinearGradient(
        colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom)
    static let idleButtonGradient = LinearGradient(
        colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom)
    static let durationGradient = LinearGradient(
        colors: [.primary, .secondary], startPoint: .leading, endPoint: .trailing)
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
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(MenuStyle.durationGradient)
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
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? MenuStyle.recordButtonGradient : MenuStyle.idleButtonGradient)
                    .frame(width: Constants.UI.controlButtonSize, height: Constants.UI.controlButtonSize)
                    .scaleEffect(isHovering ? 1.05 : 1.0)

                Image(systemName: isRecording ? "stop.fill" : "record.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(isRecording ? 0.8 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRecording)
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
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
