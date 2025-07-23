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
    
    private let micRecorder = SimpleMicrophoneRecorder()
    private var systemAudioCapture: (any NSObjectProtocol)?
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusBarIcon()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        setupPopover()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 200, height: 120)
        popover?.behavior = .transient
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
        
        let iconName = isRecording ? "record.circle.fill" : "record.circle"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Microphone Recorder")
        button.image?.size = NSSize(width: 18, height: 18)
    }
    
    func startRecording() {
        Logger.shared.log("🎬 [RECORDING] User requested recording start")
        
        Task {
            do {
                Logger.shared.log("🔍 [RECORDING] Checking microphone permission...")
                
                // Quick permission check
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                let hasMicPermission = microphoneStatus == .authorized
                
                if !hasMicPermission {
                    Logger.shared.log("❌ [RECORDING] Missing microphone permission")
                    await MainActor.run {
                        errorMessage = "Permission microphone manquante. Veuillez l'autoriser dans les Préférences Système."
                    }
                    return
                }
                
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
                    errorMessage = "Échec de l'enregistrement : \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopRecording() {
        Logger.shared.log("🛑 [RECORDING] User requested recording stop")
        
        micRecorder.stopRecording()
        
        // Arrêter la capture audio système si elle est active
        if #available(macOS 13.0, *), let systemCapture = systemAudioCapture as? SystemAudioCapture {
            Task {
                await systemCapture.stopRecording()
                await MainActor.run {
                    self.systemAudioCapture = nil
                }
            }
        }
        
        isRecording = false
        recordingDuration = 0
        updateStatusBarIcon()
        stopDurationUpdater()
        
        Logger.shared.log("✅ [RECORDING] Recording stopped")
    }
    
    private var durationTimer: Timer?
    
    private func startDurationUpdater() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Utiliser la durée du microphone comme référence principale
                self.recordingDuration = self.micRecorder.recordingDuration
            }
        }
    }
    
    private func stopDurationUpdater() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    func cleanup() {
        stopDurationUpdater()
        if isRecording {
            stopRecording()
        }
        
        // Nettoyer la capture audio système
        if #available(macOS 13.0, *), let systemCapture = systemAudioCapture as? SystemAudioCapture {
            Task {
                await systemCapture.stopRecording()
            }
        }
        systemAudioCapture = nil
        
        statusItem = nil
        popover = nil
    }
}