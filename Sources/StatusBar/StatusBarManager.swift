import Cocoa
import SwiftUI
import AVFoundation

@MainActor
class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var isTeamsMeetingDetected = false
    
    private let micRecorder = SimpleMicrophoneRecorder()
    private var systemAudioCapture: (any NSObjectProtocol)?
    
    // ✨ Nouvelle API unifiée pour macOS 15+ (stored properties ne peuvent pas être @available)
    private var unifiedCapture: (any NSObjectProtocol)?
    
    // 🔍 Teams detection
    private let teamsDetector = TeamsDetector()
    private var autoRecordingEnabled = true
    private var autoStopEnabled = true
    private var endingTimer: Timer?
    private let autoStopDelay: TimeInterval = 1.0 // 1 second grace period
    
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
        
        Logger.shared.log("🔍 [TEAMS] Meeting status changed: \(isActive ? "DETECTED" : "ENDED")")
        
        if isActive {
            // Meeting started - cancel any pending auto-stop
            cancelAutoStopTimer()
            
            if autoRecordingEnabled && !isRecording {
                Logger.shared.log("🎬 [AUTO] Starting automatic recording for Teams meeting")
                startRecording()
            }
        } else {
            // Meeting ended - start grace period for auto-stop
            if autoStopEnabled && isRecording {
                Logger.shared.log("🎬 [AUTO] Teams meeting ended, will stop recording in \(Int(autoStopDelay)) seconds...")
                scheduleAutoStop()
            } else {
                Logger.shared.log("🎬 [AUTO] Teams meeting ended (auto-stop disabled, recording continues)")
            }
        }
    }
    
    private func scheduleAutoStop() {
        // Cancel any existing timer
        cancelAutoStopTimer()
        
        // Schedule new auto-stop timer
        endingTimer = Timer.scheduledTimer(withTimeInterval: autoStopDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Double-check that meeting is still not detected and we're still recording
                if !self.isTeamsMeetingDetected && self.isRecording {
                    Logger.shared.log("🎬 [AUTO] Grace period ended - stopping recording automatically")
                    self.stopRecording()
                } else if self.isTeamsMeetingDetected {
                    Logger.shared.log("🎬 [AUTO] Teams meeting resumed during grace period - continuing recording")
                } else {
                    Logger.shared.log("🎬 [AUTO] Recording already stopped manually")
                }
                
                self.endingTimer = nil
            }
        }
    }
    
    private func cancelAutoStopTimer() {
        endingTimer?.invalidate()
        endingTimer = nil
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 360)
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
        
        let iconName: String
        let description: String
        
        if isRecording {
            iconName = "record.circle.fill"
            description = L10n.statusRecording
        } else if isTeamsMeetingDetected {
            iconName = "video.circle"
            description = L10n.statusTeamsDetected
        } else {
            iconName = "record.circle"
            description = L10n.statusReady
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: description)
        button.image?.size = NSSize(width: 18, height: 18)
        
        // Change icon color based on status
        if isTeamsMeetingDetected && !isRecording {
            button.image?.isTemplate = false
            // Make it more visible when Teams meeting is detected
        } else {
            button.image?.isTemplate = true
        }
    }
    
    func startRecording() {
        Logger.shared.log("🎬 [RECORDING] User requested recording start")
        
        Task {
            do {
                Logger.shared.log("🔍 [RECORDING] Checking permissions...")
                
                // Quick permission check
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                let hasMicPermission = microphoneStatus == .authorized
                
                if !hasMicPermission {
                    Logger.shared.log("❌ [RECORDING] Missing microphone permission")
                    await MainActor.run {
                        errorMessage = L10n.errorMicrophonePermission
                    }
                    return
                }
                
                // ✨ Utiliser l'API unifiée sur macOS 15+
                if #available(macOS 15.0, *) {
                    Logger.shared.log("🚀 [RECORDING] Using unified capture (macOS 15+)")
                    let unified = UnifiedScreenCapture()
                    try await unified.startDirectRecording()
                    unifiedCapture = unified
                } else {
                    // Fallback sur l'ancienne approche pour macOS < 15
                    Logger.shared.log("🔄 [RECORDING] Using legacy approach (macOS < 15)")
                    
                    Logger.shared.log("🎙️ [RECORDING] Starting microphone recording...")
                    try micRecorder.startRecording()
                    
                    // Démarrer la capture audio système si disponible (macOS 13+)
                    if #available(macOS 13.0, *) {
                        Logger.shared.log("🔊 [RECORDING] Starting system audio capture...")
                        let systemCapture = SystemAudioCapture()
                        try await systemCapture.startRecording()
                        systemAudioCapture = systemCapture
                        Logger.shared.log("✅ [RECORDING] System audio capture started")
                    }
                }
                
                await MainActor.run {
                    isRecording = true
                    errorMessage = nil
                    updateStatusBarIcon()
                    startDurationUpdater()
                }
                Logger.shared.log("✅ [RECORDING] Recording started successfully")
                
            } catch {
                Logger.shared.log("❌ [RECORDING] Recording start failed: \(error)")
                
                await MainActor.run {
                    errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
                }
            }
        }
    }
    
    func stopRecording() {
        Logger.shared.log("🛑 [RECORDING] User requested recording stop")
        
        Task {
            var finalFileURL: URL?
            
            // ✨ Utiliser l'API unifiée sur macOS 15+
            if #available(macOS 15.0, *), let unified = unifiedCapture as? UnifiedScreenCapture {
                Logger.shared.log("🚀 [RECORDING] Stopping unified capture")
                if let movURL = await unified.stopRecording() {
                    do {
                        Logger.shared.log("🎵 [RECORDING] Converting MOV to M4A...")
                        finalFileURL = try await unified.convertMOVToM4A(sourceURL: movURL)
                        
                        // Optionally remove the original MOV file to save space
                        try FileManager.default.removeItem(at: movURL)
                        Logger.shared.log("🗑️ [RECORDING] Original MOV file removed")
                    } catch {
                        Logger.shared.log("❌ [RECORDING] MOV to M4A conversion failed: \(error)")
                        // Keep the original MOV file if conversion fails
                        finalFileURL = movURL
                    }
                }
                unifiedCapture = nil
            } else {
                // Fallback sur l'ancienne approche pour macOS < 15
                Logger.shared.log("🔄 [RECORDING] Stopping legacy approach")
                
                var microphoneFileURL: URL?
                var systemAudioFileURL: URL?
                
                // Arrêter l'enregistrement microphone
                microphoneFileURL = micRecorder.stopRecording()
                
                // Arrêter la capture audio système si elle est active
                if #available(macOS 13.0, *), let systemCapture = systemAudioCapture as? SystemAudioCapture {
                    systemAudioFileURL = await systemCapture.stopRecording()
                    await MainActor.run {
                        self.systemAudioCapture = nil
                    }
                }
                
                // Fusionner les fichiers audio en M4A
                do {
                    Logger.shared.log("🎵 [RECORDING] Démarrage de la fusion audio...")
                    finalFileURL = try await AudioMixer.mixAudioFiles(microphoneURL: microphoneFileURL, systemAudioURL: systemAudioFileURL)
                } catch {
                    Logger.shared.log("❌ [RECORDING] Erreur lors de la fusion audio: \(error)")
                    await MainActor.run {
                        errorMessage = L10n.errorAudioMixingFailed(error.localizedDescription)
                    }
                }
            }
            
            await MainActor.run {
                isRecording = false
                recordingDuration = 0
                updateStatusBarIcon()
                stopDurationUpdater()
            }
            
            // Afficher le résultat final
            if let finalURL = finalFileURL {
                Logger.shared.log("✅ [RECORDING] Enregistrement final sauvegardé: \(finalURL.lastPathComponent)")
            } else {
                Logger.shared.log("⚠️ [RECORDING] Aucun fichier généré")
            }
        }
        
        Logger.shared.log("✅ [RECORDING] Recording stopped")
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
    
    func showOnboarding() {
        // Open onboarding window
        NSApp.activate(ignoringOtherApps: true)
        
        // Try to open onboarding window
        if let existingWindow = NSApp.windows.first(where: { 
            $0.title.contains("Configuration des Permissions") || 
            $0.identifier?.rawValue == "onboarding" 
        }) {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.center()
        } else {
            // Create new onboarding window with proper setup
            DispatchQueue.main.async {
                let onboardingView = OnboardingView()
                let hostingController = NSHostingController(rootView: onboardingView)
                
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                
                window.title = L10n.onboardingTitle
                window.contentViewController = hostingController
                window.center()
                window.isReleasedWhenClosed = false // Éviter les crashes
                window.makeKeyAndOrderFront(nil)
                window.level = .floating
                
                // Donner le focus à la fenêtre
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Teams Detection Controls
    
    func toggleAutoRecording() {
        autoRecordingEnabled.toggle()
        Logger.shared.log("🔍 [AUTO] Auto-recording \(autoRecordingEnabled ? "ENABLED" : "DISABLED")")
    }
    
    func isAutoRecordingEnabled() -> Bool {
        return autoRecordingEnabled
    }
    
    func toggleAutoStop() {
        autoStopEnabled.toggle()
        
        if !autoStopEnabled {
            // Cancel any pending auto-stop when disabled
            cancelAutoStopTimer()
        }
        
        Logger.shared.log("🔍 [AUTO] Auto-stop \(autoStopEnabled ? "ENABLED" : "DISABLED")")
    }
    
    func isAutoStopEnabled() -> Bool {
        return autoStopEnabled
    }
    
    func getAutoStopDelay() -> Int {
        return Int(autoStopDelay)
    }
    
    func hasScheduledAutoStop() -> Bool {
        return endingTimer != nil
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
        cancelAutoStopTimer()
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
        
        statusItem = nil
        popover = nil
    }
}