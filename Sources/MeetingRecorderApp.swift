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
        
        // Request all permissions at launch
        Task {
            await requestPermissionsAtLaunch()
        }
    }
    
    private func requestPermissionsAtLaunch() async {
        Logger.shared.log("🚀 MeetingRecorder starting...")
        Logger.shared.log("💻 macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        do {
            Logger.shared.log("🔐 [PERMISSIONS] Starting permission requests...")
            
            Logger.shared.log("🎤 [PERMISSIONS] Requesting microphone access...")
            try await permissionManager.requestMicrophonePermission()
            Logger.shared.log("✅ [PERMISSIONS] Microphone permission granted")
            
            if #available(macOS 12.3, *) {
                Logger.shared.log("📺 [PERMISSIONS] Requesting screen recording access...")
                try await permissionManager.requestScreenRecordingPermission()
                Logger.shared.log("✅ [PERMISSIONS] Screen recording permission granted")
            }
            
            Logger.shared.log("📅 [PERMISSIONS] Requesting calendar access...")
            try await permissionManager.requestCalendarPermission()
            Logger.shared.log("✅ [PERMISSIONS] Calendar permission granted")
            
            Logger.shared.log("🎉 [PERMISSIONS] All permissions granted successfully!")
            
        } catch {
            Logger.shared.log("❌ [ERROR] Permission request failed: \(error)")
            Logger.shared.log("📋 [ERROR] Error details: \(error.localizedDescription)")
            
            // Show alert to user about missing permissions
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Permissions requises"
                alert.informativeText = error.localizedDescription + "\n\nL'application ne fonctionnera pas correctement sans ces permissions."
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