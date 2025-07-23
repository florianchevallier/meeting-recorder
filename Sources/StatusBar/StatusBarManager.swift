import Cocoa
import SwiftUI

@MainActor
class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    
    private let audioRecorder = AudioRecorder()
    
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
        popover?.contentSize = NSSize(width: 200, height: 100)
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
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Meeting Recorder")
        button.image?.size = NSSize(width: 18, height: 18)
    }
    
    func startRecording() {
        Logger.shared.log("🎬 [RECORDING] User requested recording start")
        
        Task {
            do {
                Logger.shared.log("🔍 [RECORDING] Checking permissions before start...")
                
                // Check permissions before starting recording
                let permissionManager = PermissionManager()
                let status = await permissionManager.checkAllPermissions()
                
                Logger.shared.log("📋 [RECORDING] Permission status: \(status)")
                
                if status != .allGranted {
                    Logger.shared.log("❌ [RECORDING] Missing permissions, cannot start")
                    await MainActor.run {
                        errorMessage = "Permissions manquantes. Veuillez vérifier l'accès au microphone et à l'enregistrement d'écran dans les Préférences Système."
                    }
                    return
                }
                
                Logger.shared.log("🎙️ [RECORDING] Starting audio recording...")
                try await audioRecorder.startRecording()
                
                await MainActor.run {
                    isRecording = true
                    errorMessage = nil
                    updateStatusBarIcon()
                    startDurationUpdater()
                }
                Logger.shared.log("✅ [RECORDING] Recording started successfully")
                
            } catch {
                Logger.shared.log("❌ [RECORDING] Recording start failed: \(error)")
                Logger.shared.log("📋 [RECORDING] Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopRecording() {
        Task {
            await audioRecorder.stopRecording()
            isRecording = false
            recordingDuration = 0
            updateStatusBarIcon()
            stopDurationUpdater()
            print("Recording stopped")
        }
    }
    
    private var durationTimer: Timer?
    
    private func startDurationUpdater() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = self.audioRecorder.recordingDuration
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
        statusItem = nil
        popover = nil
    }
}