import SwiftUI
import Cocoa

@main
struct MeetingRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // WindowGroup caché - l'app fonctionne uniquement via la status bar
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager?
    private let permissionManager = PermissionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Masquer toutes les fenêtres existantes
        NSApp.windows.forEach { $0.orderOut(nil) }
        
        // Configuration comme accessory app (pas d'icône dans le dock)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup status bar first
        statusBarManager = StatusBarManager()
        statusBarManager?.setupStatusBar()
        
        // Vérifier l'onboarding après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if OnboardingManager.shared.shouldShowOnboarding {
                self?.showOnboarding()
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Empêcher la réouverture de fenêtres - on utilise uniquement la status bar
        return false
    }
    
    @MainActor
    private func showOnboarding() {
        // Utiliser directement le StatusBarManager pour afficher l'onboarding
        statusBarManager?.showOnboarding()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarManager?.cleanup()
    }
}