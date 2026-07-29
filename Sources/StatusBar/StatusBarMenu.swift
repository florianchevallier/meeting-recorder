import SwiftUI

/// Status bar popover menu. Reads `RecordingCoordinator` (@Observable) and
/// `PermissionMonitor`; transcription state flows through
/// `coordinator.transcription.state` (@Observable struct).
struct StatusBarMenu: View {
    let coordinator: RecordingCoordinator
    let permissionMonitor: PermissionMonitor
    let onOpenSettings: () -> Void

    @State private var isHovering = false

    init(
        coordinator: RecordingCoordinator,
        permissionMonitor: PermissionMonitor,
        onOpenSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.permissionMonitor = permissionMonitor
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            mainControlSection
            errorSection
            transcriptionSection
            quickActionsSection
        }
        .background(VisualEffectView())
        .frame(width: Constants.UI.menuWidth)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.appName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(L10n.appSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusIndicator
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    coordinator.isStopping ?
                    .linearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom) :
                    coordinator.isRecording ?
                    .linearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom) :
                    coordinator.isTeamsMeetingDetected ?
                    .linearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom) :
                    .linearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 8, height: 8)
                .scaleEffect(coordinator.isRecording || coordinator.isStopping || coordinator.isTeamsMeetingDetected ? 1.2 : 1.0)
                .animation(
                    coordinator.isRecording ?
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    coordinator.isStopping ?
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                    coordinator.isTeamsMeetingDetected ?
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true) :
                        .default,
                    value: coordinator.isRecording || coordinator.isStopping || coordinator.isTeamsMeetingDetected
                )

            Text(coordinator.isStopping ? L10n.statusFinishingShort :
                 coordinator.isRecording ? L10n.statusRecordingShort :
                 coordinator.isTeamsMeetingDetected ? L10n.statusTeamsShort : L10n.statusIdle)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(coordinator.isStopping ? .orange :
                                coordinator.isRecording ? .red :
                                coordinator.isTeamsMeetingDetected ? .blue : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Main Control Section

    private var mainControlSection: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let duration = recordingDuration(at: context.date)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(.separatorColor), lineWidth: 1)
                        .frame(
                            width: Constants.UI.controlCircleSize,
                            height: Constants.UI.controlCircleSize
                        )

                    if coordinator.isRecording {
                        Circle()
                            .trim(
                                from: 0,
                                to: min(duration / Constants.UI.maxRecordingDurationForProgress, 1.0)
                            )
                            .stroke(
                                .linearGradient(
                                    colors: [.red, .orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: Constants.UI.progressRingLineWidth,
                                    lineCap: .round
                                )
                            )
                            .frame(
                                width: Constants.UI.controlCircleSize,
                                height: Constants.UI.controlCircleSize
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    if coordinator.isStopping {
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.2)
                    } else {
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(coordinator.isRecording ?
                                          .linearGradient(
                                            colors: [.red.opacity(0.8), .red],
                                            startPoint: .top,
                                            endPoint: .bottom
                                          ) :
                                          .linearGradient(
                                            colors: [.blue.opacity(0.8), .blue],
                                            startPoint: .top,
                                            endPoint: .bottom
                                          )
                                    )
                                    .frame(
                                        width: Constants.UI.controlButtonSize,
                                        height: Constants.UI.controlButtonSize
                                    )
                                    .scaleEffect(isHovering ? 1.05 : 1.0)

                                Image(systemName: coordinator.isRecording ? "stop.fill" : "record.circle")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white)
                                    .scaleEffect(coordinator.isRecording ? 0.8 : 1.0)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: coordinator.isRecording)
                    }
                }

                recordingInfoSection(duration: duration)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Recording Info Section

    private func recordingInfoSection(duration: TimeInterval) -> some View {
        VStack(spacing: 8) {
            if coordinator.isRecording {
                VStack(spacing: 4) {
                    Text(formatDuration(duration))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.linearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))

                    Text(L10n.statusRecording)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            } else if coordinator.isStopping {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.statusFinishing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Text(coordinator.isTeamsMeetingDetected ? L10n.statusTeamsDetected : L10n.statusReady)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(coordinator.isTeamsMeetingDetected ? .blue : .primary)

                    if coordinator.isTeamsMeetingDetected {
                        HStack(spacing: 4) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text(L10n.statusTeamsActive)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    } else {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text(L10n.audioMicrophone)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text(L10n.audioSystem)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: coordinator.isRecording)
    }

    // MARK: - Transcription Section

    @ViewBuilder
    private var transcriptionSection: some View {
        if coordinator.transcription.state.isTranscribing {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "waveform.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                            .symbolEffect(.pulse, options: .repeating)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionRunning)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(coordinator.transcription.state.progress)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
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
                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(error)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
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
            Divider()
                .padding(.horizontal, 20)

            HStack(spacing: 0) {
                QuickActionButton(
                    icon: "folder.fill",
                    title: L10n.actionFolder,
                    action: openRecordingsFolder
                )

                Divider()
                    .frame(height: Constants.UI.quickActionHeight)

                QuickActionButton(
                    icon: "gearshape.fill",
                    title: L10n.actionSettings,
                    action: onOpenSettings
                )
            }
            .frame(height: Constants.UI.quickActionHeight)
        }
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Error Message

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = coordinator.errorMessage {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text(errorMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer()
                    }

                    if permissionMonitor.screenRecordingPermission != .authorized {
                        Button(action: {
                            permissionMonitor.openScreenRecordingSettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "gear")
                                    .font(.system(size: 10, weight: .medium))
                                Text(L10n.menuErrorAuthorizeScreen)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
            }
        }
    }

    // MARK: - Helpers

    private func recordingDuration(at date: Date) -> TimeInterval {
        guard let startedAt = coordinator.recordingStartedAt else { return 0 }
        return date.timeIntervalSince(startedAt)
    }

    private func toggleRecording() {
        guard !coordinator.isStopping else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if coordinator.isRecording {
                coordinator.stop()
            } else {
                coordinator.start()
            }
        }
    }

    private func openRecordingsFolder() {
        guard let documentsURL = FileSystemUtilities.getDocumentsDirectory() else {
            Logger.shared.error("Unable to open Documents directory", component: "UI")
            return
        }
        NSWorkspace.shared.open(documentsURL)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Quick Action Button

/// Quick action with an Option-key alternate action/icon/title.
/// The flagsChanged monitor is stored and removed on disappear —
/// the old code accumulated one monitor per appearance, forever.
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    let isDestructive: Bool
    let isActive: Bool
    let alternateAction: (() -> Void)?
    let alternateIcon: String?
    let alternateTitle: String?

    @State private var isHovering = false
    @State private var isOptionPressed = false
    @State private var flagsMonitor: Any?

    init(
        icon: String,
        title: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false,
        isActive: Bool = false,
        alternateAction: (() -> Void)? = nil,
        alternateIcon: String? = nil,
        alternateTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.action = action
        self.isDestructive = isDestructive
        self.isActive = isActive
        self.alternateAction = alternateAction
        self.alternateIcon = alternateIcon
        self.alternateTitle = alternateTitle
    }

    var body: some View {
        Button(action: {
            if isOptionPressed, let alternateAction {
                alternateAction()
            } else {
                action()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isOptionPressed ? (alternateIcon ?? icon) : icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? .red : isActive ? .blue : .primary)

                Text(isOptionPressed ? (alternateTitle ?? title) : title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDestructive ? .red : isActive ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isOptionPressed = event.modifierFlags.contains(.option)
                return event
            }
        }
        .onDisappear {
            if let flagsMonitor {
                NSEvent.removeMonitor(flagsMonitor)
            }
            flagsMonitor = nil
        }
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
