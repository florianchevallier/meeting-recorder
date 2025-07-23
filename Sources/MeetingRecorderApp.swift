import SwiftUI
import Cocoa

@main
struct MeetingRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager?
    private let permissionManager = PermissionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusBarManager = StatusBarManager()
        statusBarManager?.setupStatusBar()
        
        // Request only microphone permission
        Task {
            await requestMicrophonePermission()
        }
    }
    
    private func requestMicrophonePermission() async {
        Logger.shared.log("🚀 MeetingRecorder starting...")
        Logger.shared.log("💻 macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        do {
            Logger.shared.log("🔐 [PERMISSIONS] Starting microphone permission request...")
            
            Logger.shared.log("🎤 [PERMISSIONS] Requesting microphone access...")
            try await permissionManager.requestMicrophonePermission()
            Logger.shared.log("✅ [PERMISSIONS] Microphone permission granted")
            
            Logger.shared.log("🎉 [PERMISSIONS] Ready to record!")
            
        } catch {
            Logger.shared.log("❌ [ERROR] Microphone permission failed: \(error)")
            Logger.shared.log("📋 [ERROR] Error details: \(error.localizedDescription)")
            
            // Show alert to user about missing permission
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Permission microphone requise"
                alert.informativeText = error.localizedDescription + "\n\nL'application ne peut pas enregistrer sans accès au microphone."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Ouvrir Préférences Système")
                alert.addButton(withTitle: "Continuer")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Preferences
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        Logger.shared.log("🔧 [DEBUG] Opening System Preferences...")
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarManager?.cleanup()
    }
}