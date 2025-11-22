import Foundation
import SwiftUI
import AVFoundation
import ScreenCaptureKit
import Cocoa
import ApplicationServices
import CoreMedia

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    private let accessibilityPromptedKey = "PermissionManager.accessibilityPrompted"
    
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var screenRecordingPermission: PermissionStatus = .notDetermined
    @Published var documentsPermission: PermissionStatus = .notDetermined
    @Published var accessibilityPermission: PermissionStatus = .notDetermined
    
    private var accessibilityMonitorTask: Task<Void, Never>?
    private var appActiveObserver: NSObjectProtocol?
    
    private init() {
        checkAllPermissions()
        
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Re-vérifier toutes les permissions quand l'app redevient active
            // (utile après avoir ouvert les Préférences Système)
            self?.checkAllPermissions()
        }
    }

    private var hasPromptedAccessibility: Bool {
        get { UserDefaults.standard.bool(forKey: accessibilityPromptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessibilityPromptedKey) }
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
        // Méthode améliorée pour détecter correctement la permission d'enregistrement d'écran
        // Nécessaire car macOS a deux types de permissions différentes
        Task {
            var hasPermission = false
            var lastError: Error?
            
            // Méthode 1: Essayer avec excludingDesktopWindows (pour compatibilité)
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                hasPermission = !content.displays.isEmpty
                if hasPermission {
                    Logger.shared.log("🔍 [PERMISSIONS] Screen recording permission detected via excludingDesktopWindows")
                }
            } catch {
                lastError = error
                Logger.shared.log("🔍 [PERMISSIONS] excludingDesktopWindows failed: \(error.localizedDescription)")
            }
            
            // Méthode 2: Essayer avec SCShareableContent.current (plus récent, macOS 15+)
            if !hasPermission {
                do {
                    let content = try await SCShareableContent.current
                    hasPermission = !content.displays.isEmpty
                    if hasPermission {
                        Logger.shared.log("🔍 [PERMISSIONS] Screen recording permission detected via SCShareableContent.current")
                    }
                } catch {
                    if lastError == nil {
                        lastError = error
                    }
                    Logger.shared.log("🔍 [PERMISSIONS] SCShareableContent.current failed: \(error.localizedDescription)")
                }
            }
            
            // Méthode 3: Essayer de créer un stream minimal pour confirmer la permission
            if !hasPermission {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    if let display = content.displays.first {
                        let config = SCStreamConfiguration()
                        config.width = 1
                        config.height = 1
                        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                        let filter = SCContentFilter(display: display, excludingWindows: [])
                        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                        try await stream.startCapture()
                        try await stream.stopCapture()
                        hasPermission = true
                        Logger.shared.log("🔍 [PERMISSIONS] Screen recording permission confirmed via test stream")
                    }
                } catch {
                    Logger.shared.log("🔍 [PERMISSIONS] Test stream creation failed: \(error.localizedDescription)")
                    // Analyser le code d'erreur pour déterminer si c'est vraiment un refus de permission
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.ScreenCaptureKit" && nsError.code == -3801 {
                        // Code d'erreur spécifique pour permission refusée
                        Logger.shared.log("🔍 [PERMISSIONS] Permission explicitly denied (error code -3801)")
                    } else {
                        // Autre erreur, peut-être temporaire - ne pas considérer comme refusé
                        Logger.shared.log("🔍 [PERMISSIONS] Unknown error - assuming permission may be granted but API call failed")
                    }
                }
            }
            
            DispatchQueue.main.async {
                if hasPermission {
                    self.screenRecordingPermission = .authorized
                    Logger.shared.log("✅ [PERMISSIONS] Screen recording permission: AUTHORIZED")
                } else if let error = lastError {
                    let nsError = error as NSError
                    // Seulement marquer comme refusé si c'est vraiment une erreur de permission
                    if nsError.domain == "com.apple.ScreenCaptureKit" && (nsError.code == -3801 || nsError.code == -3804) {
                        self.screenRecordingPermission = .denied
                        Logger.shared.log("❌ [PERMISSIONS] Screen recording permission: DENIED")
                    } else {
                        // Erreur inconnue, ne pas marquer comme refusé mais comme non déterminé
                        self.screenRecordingPermission = .notDetermined
                        Logger.shared.log("⚠️ [PERMISSIONS] Screen recording permission: UNCLEAR (error: \(error.localizedDescription))")
                    }
                } else {
                    self.screenRecordingPermission = .notDetermined
                    Logger.shared.log("⚠️ [PERMISSIONS] Screen recording permission: NOT DETERMINED")
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
        hasPromptedAccessibility = true

        // Déclencher l'invite du système si nécessaire
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        openAccessibilitySettings()
        checkAccessibilityPermission() // Mise à jour immédiate
        startAccessibilityStatusMonitor()
    }
    
    // MARK: - Open System Preferences
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
        
        // Programmer une re-vérification après un délai pour laisser macOS appliquer les changements
        Task {
            // Attendre que l'utilisateur ferme les Préférences Système
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
            
            // Re-vérifier la permission plusieurs fois avec des délais
            for _ in 0..<5 {
                checkScreenRecordingPermission()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde entre chaque vérification
            }
        }
    }
    
    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    func openAccessibilitySettings() {
        // Sur macOS Ventura+ (13.0+), l'Accessibilité est une section principale
        // Sur macOS Sequoia (15.0+), utilise System Settings avec navigation
        
        if #available(macOS 15.0, *) {
            // macOS Sequoia+: Ouvrir System Settings et naviguer vers Accessibilité
            // Utiliser AppleScript pour ouvrir directement la bonne section
            let script = """
                tell application "System Settings"
                    activate
                    reveal anchor "Privacy_Accessibility" of pane id "com.apple.preference.security"
                end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if error != nil {
                    // Fallback: Ouvrir System Settings normalement
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else if #available(macOS 13.0, *) {
            // macOS Ventura: Essayer d'ouvrir directement la section Accessibilité
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess") {
                NSWorkspace.shared.open(url)
            } else {
                // Fallback vers Confidentialité et sécurité
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS Monterey et antérieur: Utiliser le prefPane
            let prefPanePath = "/System/Library/PreferencePanes/UniversalAccessPref.prefPane"
            if FileManager.default.fileExists(atPath: prefPanePath) {
                NSWorkspace.shared.openFile(prefPanePath, withApplication: "System Preferences")
            } else {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        let hasWindowAccess = trusted ? true : testWindowAccess()

        if trusted {
            hasPromptedAccessibility = true
        }
        
        DispatchQueue.main.async {
            let newStatus: PermissionStatus
            if trusted || hasWindowAccess {
                newStatus = .authorized
            } else if self.hasPromptedAccessibility {
                newStatus = .denied
            } else {
                newStatus = .notDetermined
            }
            
            if self.accessibilityPermission != newStatus {
                Logger.shared.log("🔐 [ACCESSIBILITY] Permission status updated to: \(newStatus.rawValue) (trusted=\(trusted), windowAccess=\(hasWindowAccess))")
            }
            
            self.accessibilityPermission = newStatus
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

    private func startAccessibilityStatusMonitor() {
        accessibilityMonitorTask?.cancel()
        accessibilityMonitorTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<20 {
                if Task.isCancelled { return }

                if AXIsProcessTrusted() {
                    await MainActor.run {
                        self.accessibilityPermission = .authorized
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            await MainActor.run {
                if self.hasPromptedAccessibility {
                    self.accessibilityPermission = .denied
                } else {
                    self.accessibilityPermission = .notDetermined
                }
            }
        }
    }
    
    deinit {
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        accessibilityMonitorTask?.cancel()
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
