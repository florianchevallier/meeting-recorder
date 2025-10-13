import SwiftUI

struct StatusBarMenu: View {
    @ObservedObject var statusBarManager: StatusBarManager
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var isHovering = false
    @State private var audioLevel: Double = 0.0

    init(statusBarManager: StatusBarManager) {
        self.statusBarManager = statusBarManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
            
            // Main Control Section
            mainControlSection
            
            // Error Section (if any)
            errorSection

            // Transcription Section (if active)
            transcriptionSection

            // Quick Actions Section
            quickActionsSection
        }
        .background(VisualEffectView())
        .frame(width: 280)
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
                    statusBarManager.isStoppingRecording ?
                    .linearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom) :
                    statusBarManager.isRecording ?
                    .linearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom) :
                    statusBarManager.isTeamsMeetingDetected ?
                    .linearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom) :
                    .linearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 8, height: 8)
                .scaleEffect(statusBarManager.isRecording || statusBarManager.isStoppingRecording || statusBarManager.isTeamsMeetingDetected ? 1.2 : 1.0)
                .animation(
                    statusBarManager.isRecording ?
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    statusBarManager.isStoppingRecording ?
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                    statusBarManager.isTeamsMeetingDetected ?
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true) :
                        .default,
                    value: statusBarManager.isRecording || statusBarManager.isStoppingRecording || statusBarManager.isTeamsMeetingDetected
                )
            
            Text(statusBarManager.isStoppingRecording ? L10n.statusFinishingShort :
                 statusBarManager.isRecording ? L10n.statusRecordingShort :
                 statusBarManager.isTeamsMeetingDetected ? L10n.statusTeamsShort : L10n.statusIdle)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(statusBarManager.isStoppingRecording ? .orange :
                                statusBarManager.isRecording ? .red :
                                statusBarManager.isTeamsMeetingDetected ? .blue : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(Capsule())
    }
    
    // MARK: - Main Control Section
    private var mainControlSection: some View {
        VStack(spacing: 16) {
            // Central Control Circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.separatorColor), lineWidth: 1)
                    .frame(width: 120, height: 120)
                
                // Progress ring (when recording)
                if statusBarManager.isRecording {
                    Circle()
                        .trim(from: 0, to: min(statusBarManager.recordingDuration / 3600, 1.0)) // Max 1 hour
                        .stroke(
                            .linearGradient(colors: [.red, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: statusBarManager.recordingDuration)
                }
                
                if statusBarManager.isStoppingRecording {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.2)
                } else {
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(statusBarManager.isRecording ? 
                                      .linearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) :
                                      .linearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 80, height: 80)
                                .scaleEffect(isHovering ? 1.05 : 1.0)
                            
                            Image(systemName: statusBarManager.isRecording ? "stop.fill" : "record.circle")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                                .scaleEffect(statusBarManager.isRecording ? 0.8 : 1.0)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: statusBarManager.isRecording)
                }
            }
            
            // Recording info
            recordingInfoSection
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Recording Info Section
    private var recordingInfoSection: some View {
        VStack(spacing: 8) {
            if statusBarManager.isRecording {
                VStack(spacing: 4) {
                    Text(formatDuration(statusBarManager.recordingDuration))
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
            } else if statusBarManager.isStoppingRecording {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.statusFinishing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Text(statusBarManager.isTeamsMeetingDetected ? L10n.statusTeamsDetected : L10n.statusReady)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(statusBarManager.isTeamsMeetingDetected ? .blue : .primary)
                    
                    if statusBarManager.isTeamsMeetingDetected {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "video.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text(L10n.statusTeamsActive)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
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
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: statusBarManager.isRecording)
    }
    
    // MARK: - Transcription Section
    @ViewBuilder
    private var transcriptionSection: some View {
        if statusBarManager.transcriptionManager.state.isTranscribing {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    // Animated icon
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
                        Text("Transcription en cours...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(statusBarManager.transcriptionManager.state.progress)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status indicator
                    if statusBarManager.transcriptionManager.state.status == .running {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.05))
            }
        } else if let error = statusBarManager.transcriptionManager.state.error {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erreur de transcription")
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
                    .frame(height: 44)

                QuickActionButton(
                    icon: "gearshape.fill",
                    title: L10n.actionSettings,
                    action: { statusBarManager.showSettings() }
                )
            }
            .frame(height: 44)
        }
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Error Message
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = statusBarManager.errorMessage {
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
                    
                    // Bouton Autoriser pour l'enregistrement d'écran
                    if statusBarManager.permissionManager.screenRecordingPermission != .authorized {
                        Button(action: {
                            statusBarManager.permissionManager.openScreenRecordingSettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "gear")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Autoriser l'enregistrement d'écran")
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
    
    // MARK: - Helper Methods
    private func toggleRecording() {
        guard !statusBarManager.isStoppingRecording else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if statusBarManager.isRecording {
                statusBarManager.stopRecording()
            } else {
                statusBarManager.startRecording()
            }
        }
    }
    
    private func openRecordingsFolder() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        NSWorkspace.shared.open(documentsURL)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
}

// MARK: - Quick Action Button
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
            if isOptionPressed, let altAction = alternateAction {
                altAction()
            } else {
                action()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isOptionPressed && alternateIcon != nil ? alternateIcon! : icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? .red : isActive ? .blue : .primary)

                Text(isOptionPressed && alternateTitle != nil ? alternateTitle! : title)
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
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isOptionPressed = event.modifierFlags.contains(.option)
                return event
            }
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
