import Cocoa
import SwiftUI
import AVFoundation

@MainActor
final class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var isTeamsMeetingDetected = false
    @Published var isStoppingRecording = false
    
    let permissionManager = PermissionManager.shared
    private let micRecorder = SimpleMicrophoneRecorder()
    private var systemAudioCapture: (any NSObjectProtocol)?

    // ✨ Nouvelle API unifiée pour macOS 15+ (stored properties ne peuvent pas être @available)
    private var unifiedCapture: (any NSObjectProtocol)?

    // 🔍 Teams detection
    private let teamsDetector = TeamsDetector()
    private var autoRecordingEnabled = true

    // 🎤 Transcription manager
    let transcriptionManager = TranscriptionManager()
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusBarIcon()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        setupPopover()
        setupTeamsDetection()
    }
    
    private func setupTeamsDetection() {
        // Start Teams monitoring
        teamsDetector.startMonitoring()
        
        // Listen for Teams meeting status changes
        NotificationCenter.default.addObserver(
            forName: .teamsMeetingStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let isActive = notification.userInfo?["isActive"] as? Bool else { return }
            
            Task { @MainActor in
                self.handleTeamsMeetingStatusChange(isActive: isActive)
            }
        }
    }
    
    private func handleTeamsMeetingStatusChange(isActive: Bool) {
        isTeamsMeetingDetected = isActive
        updateStatusBarIcon()
        
        Logger.shared.info("Meeting status changed: \(isActive ? "DETECTED" : "ENDED")", component: "TEAMS")
        
        if isActive {
            if autoRecordingEnabled && !isRecording {
                Logger.shared.info("Starting automatic recording for Teams meeting", component: "AUTO")
                startRecording()
            }
        } else {
            Logger.shared.info("Teams meeting ended (recording continues)", component: "AUTO")
        }
    }
    
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: Constants.UI.menuWidth, height: Constants.UI.menuHeight)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: StatusBarMenu(statusBarManager: self))
    }
    
    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let description: String
        
        if isStoppingRecording {
            description = L10n.statusFinishing
        } else if isRecording {
            description = L10n.statusRecording
        } else if isTeamsMeetingDetected {
            description = L10n.statusTeamsDetected
        } else {
            description = L10n.statusReady
        }
        
        // Fallback vers les icônes système (gardons l'existant qui fonctionne bien)
        let iconName: String
        
        if isStoppingRecording {
            iconName = "hourglass.circle"
        } else if isRecording {
            iconName = "record.circle.fill"
        } else if isTeamsMeetingDetected {
            iconName = "video.circle"
        } else {
            iconName = "record.circle"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: description)
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
        button.alphaValue = 1.0
        button.toolTip = description
    }
    
    private func loadAppIcon() -> NSImage? {
        // Pour Swift Package Manager, utiliser Bundle.module
        if let resourceURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png", subdirectory: "Resources/Images"),
           let image = NSImage(contentsOf: resourceURL) {
            // Créer une version optimisée pour la status bar
            let statusBarImage = NSImage(size: NSSize(width: 18, height: 18))
            statusBarImage.lockFocus()
            image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            statusBarImage.unlockFocus()
            return statusBarImage
        }
        
        // Fallback: essayer de charger directement depuis les ressources du bundle principal
        if let image = NSImage(named: "AppIcon") {
            let statusBarImage = NSImage(size: NSSize(width: 18, height: 18))
            statusBarImage.lockFocus()
            image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            statusBarImage.unlockFocus()
            return statusBarImage
        }
        
        // Essayer avec Bundle.main en dernier recours
        if let resourcePath = Bundle.main.path(forResource: "AppIcon", ofType: "png", inDirectory: "Resources/Images"),
           let image = NSImage(contentsOfFile: resourcePath) {
            let statusBarImage = NSImage(size: NSSize(width: 18, height: 18))
            statusBarImage.lockFocus()
            image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            statusBarImage.unlockFocus()
            return statusBarImage
        }
        
        return nil
    }
    
    func startRecording() {
        Logger.shared.info("User requested recording start", component: "RECORDING")
        
        guard !isStoppingRecording else {
            Logger.shared.warning("Stop in progress - start request ignored", component: "RECORDING")
            return
        }
        
        Task {
            do {
                Logger.shared.debug("Checking permissions...", component: "RECORDING")
                
                // Quick permission check
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                let hasMicPermission = microphoneStatus == .authorized
                
                if !hasMicPermission {
                    Logger.shared.error("Missing microphone permission", component: "RECORDING")
                    await MainActor.run {
                        errorMessage = L10n.errorMicrophonePermission
                    }
                    return
                }
                
                // ✨ Utiliser l'API unifiée sur macOS 15+
                if #available(macOS 15.0, *) {
                    Logger.shared.info("Using unified capture (macOS 15+)", component: "RECORDING")
                    let unified = UnifiedScreenCapture()
                    
                    // Configurer les callbacks de diagnostic
                    unified.onCriticalError = { [weak self] error in
                        Logger.shared.error("Critical error received: \(error)", component: "RECORDING")
                        Task { @MainActor in
                            self?.errorMessage = "Erreur critique d'enregistrement: \(error.localizedDescription)"
                            self?.isRecording = false
                        }
                    }
                    
                    unified.onRecoveryAttempt = { [weak self] attemptNumber in
                        Logger.shared.info("Recovery attempt \(attemptNumber)", component: "RECORDING")
                        Task { @MainActor in
                            self?.errorMessage = "Tentative de récupération \(attemptNumber)/3..."
                        }
                    }
                    
                    unified.onRecoverySuccess = { [weak self] in
                        Logger.shared.info("Recovery successful!", component: "RECORDING")
                        Task { @MainActor in
                            self?.errorMessage = nil
                        }
                    }
                    
                    try await unified.startDirectRecording()
                    unifiedCapture = unified
                } else {
                    // Fallback sur l'ancienne approche pour macOS < 15
                    Logger.shared.info("Using legacy approach (macOS < 15)", component: "RECORDING")
                    
                    Logger.shared.info("Starting microphone recording...", component: "RECORDING")
                    try micRecorder.startRecording()
                    
                    // Démarrer la capture audio système si disponible (macOS 13+)
                    if #available(macOS 13.0, *) {
                        Logger.shared.info("Starting system audio capture...", component: "RECORDING")
                        let systemCapture = SystemAudioCapture()
                        try await systemCapture.startRecording()
                        systemAudioCapture = systemCapture
                        Logger.shared.info("System audio capture started", component: "RECORDING")
                    }
                }
                
                await MainActor.run {
                    isRecording = true
                    isStoppingRecording = false
                    errorMessage = nil
                    updateStatusBarIcon()
                    startDurationUpdater()
                }
                Logger.shared.info("Recording started successfully", component: "RECORDING")
                
            } catch {
                Logger.shared.error("Recording start failed: \(error)", component: "RECORDING")
                
                await MainActor.run {
                    errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
                }
            }
        }
    }
    
    func stopRecording() {
        guard !isStoppingRecording else {
            Logger.shared.warning("Stop already in progress", component: "RECORDING")
            return
        }
        
        Logger.shared.info("User requested recording stop", component: "RECORDING")
        
        isStoppingRecording = true
        stopDurationUpdater()
        isRecording = false
        updateStatusBarIcon()
        
        Task { [weak self] in
            guard let self else { return }
            var finalFileURL: URL?
            
            defer {
                Task { @MainActor in
                    self.isRecording = false
                    self.recordingDuration = 0
                    self.isStoppingRecording = false
                    self.updateStatusBarIcon()
                }
            }
            
            // 🎤 Pre-indicate transcription if enabled (before conversion to show UI faster)
            let shouldTranscribe = SettingsManager.shared.transcriptionEnabled
            if shouldTranscribe {
                await MainActor.run {
                    self.transcriptionManager.state.updateProgress("⏳ Préparation de la transcription...")
                    self.transcriptionManager.state.isTranscribing = true
                    Logger.shared.debug("Pre-indication shown to user", component: "TRANSCRIPTION")
                }
            }

            // ✨ Utiliser l'API unifiée sur macOS 15+
            if #available(macOS 15.0, *), let unified = self.unifiedCapture as? UnifiedScreenCapture {
                Logger.shared.info("Stopping unified capture", component: "RECORDING")
                if let movURL = await unified.stopRecording() {
                    do {
                        Logger.shared.info("Converting MOV to M4A...", component: "RECORDING")
                        if shouldTranscribe {
                            await MainActor.run {
                                self.transcriptionManager.state.updateProgress("🔄 Conversion en cours...")
                            }
                        }
                        finalFileURL = try await unified.convertMOVToM4A(sourceURL: movURL)

                        try FileManager.default.removeItem(at: movURL)
                        Logger.shared.debug("Original MOV file removed", component: "RECORDING")
                    } catch {
                        Logger.shared.error("MOV to M4A conversion failed: \(error)", component: "RECORDING")
                        finalFileURL = movURL
                        await MainActor.run {
                            self.errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
                        }
                    }
                }
                await MainActor.run {
                    self.unifiedCapture = nil
                }
            } else {
                Logger.shared.info("Stopping legacy approach", component: "RECORDING")

                var microphoneFileURL: URL?
                var systemAudioFileURL: URL?

                microphoneFileURL = self.micRecorder.stopRecording()

                if #available(macOS 13.0, *), let systemCapture = self.systemAudioCapture as? SystemAudioCapture {
                    systemAudioFileURL = await systemCapture.stopRecording()
                    await MainActor.run {
                        self.systemAudioCapture = nil
                    }
                }

                do {
                    Logger.shared.info("Starting audio mixing...", component: "RECORDING")
                    if shouldTranscribe {
                        await MainActor.run {
                            self.transcriptionManager.state.updateProgress("🔄 Fusion audio en cours...")
                        }
                    }
                    finalFileURL = try await AudioMixer.mixAudioFiles(microphoneURL: microphoneFileURL, systemAudioURL: systemAudioFileURL)
                } catch {
                    Logger.shared.error("Audio mixing failed: \(error)", component: "RECORDING")
                    await MainActor.run {
                        self.errorMessage = L10n.errorAudioMixingFailed(error.localizedDescription)
                    }
                }
            }

            if let finalURL = finalFileURL {
                Logger.shared.info("Final recording saved: \(finalURL.lastPathComponent)", component: "RECORDING")

                // 🎤 Start actual transcription if enabled
                if shouldTranscribe {
                    Logger.shared.info("Starting transcription for: \(finalURL.lastPathComponent)", component: "TRANSCRIPTION")
                    await MainActor.run {
                        self.transcriptionManager.state.updateProgress("📤 Upload vers API...")
                    }
                    // Note: Utiliser [weak self] explicitement pour éviter les captures fortes
                    Task { [weak self] in
                        guard let self else { return }
                        await self.transcriptionManager.transcribe(audioFileURL: finalURL)
                    }
                } else {
                    Logger.shared.debug("Transcription disabled in settings", component: "TRANSCRIPTION")
                }
            } else {
                Logger.shared.warning("No file generated", component: "RECORDING")
                if shouldTranscribe {
                    await MainActor.run {
                        self.transcriptionManager.state.setError("Pas de fichier audio généré")
                    }
                }
            }

            Logger.shared.info("Stop sequence completed", component: "RECORDING")
        }
        
        Logger.shared.info("Recording stop requested", component: "RECORDING")
    }
    
    private var durationTimer: Timer?
    
    private func startDurationUpdater() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // ✨ Utiliser la durée de l'API unifiée sur macOS 15+
                if #available(macOS 15.0, *), let unified = self.unifiedCapture as? UnifiedScreenCapture {
                    self.recordingDuration = unified.recordingDuration
                } else {
                    // Fallback sur la durée du microphone pour l'ancienne approche
                    self.recordingDuration = self.micRecorder.recordingDuration
                }
            }
        }
    }
    
    private func stopDurationUpdater() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    func showSettings(selectedTab: Int = 0) {
        Logger.shared.info("Opening settings window (tab: \(selectedTab))", component: "SETTINGS")

        let tab = SettingsWindow.SettingsTab(rawValue: selectedTab) ?? .general

        // Open unified settings window
        NSApp.activate(ignoringOtherApps: true)

        // Try to open existing settings window
        if let existingWindow = NSApp.windows.first(where: {
            $0.title.contains("Paramètres") ||
            $0.identifier?.rawValue == "settingsWindow"
        }) {
            Logger.shared.debug("Reusing existing window", component: "SETTINGS")

            if let hostingController = existingWindow.contentViewController as? NSHostingController<SettingsWindow> {
                hostingController.rootView = SettingsWindow(statusBarManager: self, selectedTab: tab)
            }

            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.center()
        } else {
            Logger.shared.debug("Creating new window", component: "SETTINGS")
            // Create new settings window
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let settingsView = SettingsWindow(statusBarManager: self, selectedTab: tab)
                let hostingController = NSHostingController(rootView: settingsView)

                let window = NSWindow(
                    contentRect: NSRect(
                        x: 0, y: 0,
                        width: Constants.UI.windowInitialWidth,
                        height: Constants.UI.windowInitialHeight
                    ),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )

                window.title = "Meety - Paramètres"
                window.identifier = NSUserInterfaceItemIdentifier("settingsWindow")
                window.contentViewController = hostingController
                window.center()
                window.minSize = NSSize(
                    width: Constants.UI.windowMinWidth,
                    height: Constants.UI.windowMinHeight
                )
                window.maxSize = NSSize(
                    width: Constants.UI.windowMaxWidth,
                    height: Constants.UI.windowMaxHeight
                )
                window.isReleasedWhenClosed = false
                window.makeKeyAndOrderFront(nil)

                Logger.shared.info("Window created and shown", component: "SETTINGS")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // Convenience methods for specific tabs
    func showOnboarding() {
        showSettings(selectedTab: 2) // Permissions tab
    }

    func showTranscriptionSettings() {
        showSettings(selectedTab: 1) // Transcription tab
    }

    // MARK: - Teams Detection Controls
    
    func toggleAutoRecording() {
        setAutoRecordingEnabled(!autoRecordingEnabled)
    }
    
    func setAutoRecordingEnabled(_ enabled: Bool) {
        guard autoRecordingEnabled != enabled else { return }
        autoRecordingEnabled = enabled
        Logger.shared.info("Auto-recording \(enabled ? "ENABLED" : "DISABLED")", component: "AUTO")
    }
    
    func isAutoRecordingEnabled() -> Bool {
        return autoRecordingEnabled
    }
    
    
    func getTeamsStatus() -> (detected: Bool, lastCheck: Date?, method: String) {
        let status = teamsDetector.getDetectionStatus()
        return (detected: status.isActive, lastCheck: status.lastCheck, method: status.method)
    }
    
    func manualTeamsCheck() async -> Bool {
        return await teamsDetector.checkNow()
    }
    
    func cleanup() {
        stopDurationUpdater()
        if isRecording {
            stopRecording()
        }
        
        // Stop Teams detection
        teamsDetector.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
        
        // Nettoyer l'API unifiée ou la capture audio système
        if #available(macOS 15.0, *), let unified = unifiedCapture as? UnifiedScreenCapture {
            Task {
                await unified.stopRecording()
            }
            unifiedCapture = nil
        } else if #available(macOS 13.0, *), let systemCapture = systemAudioCapture as? SystemAudioCapture {
            Task {
                await systemCapture.stopRecording()
            }
        }
        systemAudioCapture = nil
        isStoppingRecording = false
        
        statusItem = nil
        popover = nil
    }
}
