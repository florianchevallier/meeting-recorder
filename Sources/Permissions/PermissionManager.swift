import Foundation
import SwiftUI
import AVFoundation
import ScreenCaptureKit
import Cocoa

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var screenRecordingPermission: PermissionStatus = .notDetermined
    @Published var documentsPermission: PermissionStatus = .notDetermined
    @Published var accessibilityPermission: PermissionStatus = .notDetermined
    
    private init() {
        checkAllPermissions()
    }
    
    // MARK: - Check All Permissions
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkScreenRecordingPermission()
        checkDocumentsPermission()
        checkAccessibilityPermission()
    }
    
    // MARK: - Microphone Permission
    func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
        checkMicrophonePermission()
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.microphonePermission = PermissionStatus(from: status)
        }
    }
    
    // MARK: - Screen Recording Permission
    func requestScreenRecordingPermission() async {
        do {
            // Essayer de démarrer une capture vide pour déclencher la demande de permission
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.width = 1
                config.height = 1
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try await stream.startCapture()
                try await stream.stopCapture()
            }
        } catch {}
        checkScreenRecordingPermission()
    }
    
    func checkScreenRecordingPermission() {
        // Méthode plus fiable pour Sequoia 2024+ 
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                // Si on obtient du contenu, la permission est accordée
                let hasPermission = !content.displays.isEmpty
                DispatchQueue.main.async {
                    self.screenRecordingPermission = hasPermission ? .authorized : .notDetermined
                }
            } catch {
                // Si erreur, permission probablement refusée
                DispatchQueue.main.async {
                    self.screenRecordingPermission = .denied
                }
            }
        }
    }
    
    // MARK: - Documents Folder Permission
    func requestDocumentsPermission() async {
        // Il n'y a pas de demande de permission standard pour les Documents.
        // L'accès est géré par le Sandboxing et les security-scoped bookmarks.
        // On se contente de vérifier l'accès.
        checkDocumentsPermission()
    }
    
    func checkDocumentsPermission() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testFileURL = documentsURL.appendingPathComponent("permission_test.tmp")
        
        var hasPermission = false
        do {
            // Essayer d'écrire et de supprimer un fichier temporaire
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            hasPermission = true
        } catch {
            hasPermission = false
        }
        
        DispatchQueue.main.async {
            self.documentsPermission = hasPermission ? .authorized : .denied
        }
    }
    
    // MARK: - Accessibility Permission
    func requestAccessibilityPermission() async {
        // Ouvrir les préférences système pour que l'utilisateur donne la permission
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        checkAccessibilityPermission() // Check immediately after opening preferences
    }
    
    // MARK: - Open System Preferences
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func checkAccessibilityPermission() {
        // Test réel : vérifier si on peut accéder aux fenêtres d'une app
        // Exactement comme le TeamsDetector le fait !
        let hasWindowAccess = testWindowAccess()
        
        DispatchQueue.main.async {
            self.accessibilityPermission = hasWindowAccess ? .authorized : .notDetermined
        }
    }
    
    /// Test si on peut vraiment accéder aux infos fenêtres (comme TeamsDetector)
    private func testWindowAccess() -> Bool {
        // Trouver une app en cours d'exécution pour tester
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        guard let finderApp = runningApps.first else {
            // Fallback : tester avec n'importe quelle app
            let allApps = NSWorkspace.shared.runningApplications
            guard let testApp = allApps.first(where: { $0.bundleIdentifier != nil }) else {
                return false
            }
            return testAppWindowAccess(app: testApp)
        }
        
        return testAppWindowAccess(app: finderApp)
    }
    
    /// Test réel d'accès aux fenêtres d'une app spécifique
    private func testAppWindowAccess(app: NSRunningApplication) -> Bool {
        guard let pid = app.processIdentifier as pid_t? else { return false }
        
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        switch result {
        case .success:
            return true  // On peut accéder aux fenêtres !
        case .apiDisabled, .failure:
            return false  // Permission refusée
        default:
            return false
        }
    }

    // MARK: - Request All Permissions
    func requestAllPermissions() async {
        await requestMicrophonePermission()
        await requestScreenRecordingPermission()
        await requestDocumentsPermission()
        await requestAccessibilityPermission()
        
        // Forcer une revérification globale après toutes les demandes
        checkAllPermissions()
    }

    // MARK: - Computed Properties
    var allPermissionsGranted: Bool {
        return microphonePermission == .authorized &&
               screenRecordingPermission == .authorized &&
               documentsPermission == .authorized &&
               accessibilityPermission == .authorized
    }
}



// MARK: - Permission Status Enum
enum PermissionStatus: String, CaseIterable {
    case notDetermined = "not_determined"
    case authorized = "authorized"
    case denied = "denied"
    case restricted = "restricted"
    
    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }
    
    var displayName: String {
        switch self {
        case .notDetermined: return L10n.permissionStatusNotDetermined
        case .authorized: return L10n.permissionStatusAuthorized
        case .denied: return L10n.permissionStatusDenied
        case .restricted: return L10n.permissionStatusRestricted
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        }
    }
}

// MARK: - Permission Errors
enum PermissionError: Error, LocalizedError {
    case microphonePermissionDenied
    case screenRecordingPermissionDenied
    case documentsPermissionDenied
    case accessibilityPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return L10n.errorMicrophonePermission
        case .screenRecordingPermissionDenied:
            return L10n.errorScreenRecordingPermission
        case .documentsPermissionDenied:
            return L10n.errorDocumentsPermission
        case .accessibilityPermissionDenied:
            return L10n.errorAccessibilityPermission
        }
    }
}

