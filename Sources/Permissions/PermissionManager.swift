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
    func requestMicrophonePermission() async throws {
        let granted = await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
        
        DispatchQueue.main.async {
            self.microphonePermission = granted ? .authorized : .denied
        }
        
        if !granted {
            throw PermissionError.microphonePermissionDenied
        }
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermission = PermissionStatus(from: status)
    }
    
    // MARK: - Screen Recording Permission
    func requestScreenRecordingPermission() async throws {
        // Pour ScreenCaptureKit, on essaie de créer un stream temporaire
        // Cela déclenchera automatiquement la demande de permission si nécessaire
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.width = 1
                config.height = 1
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try await stream.startCapture()
                try await stream.stopCapture()
                
                DispatchQueue.main.async {
                    self.screenRecordingPermission = .authorized
                }
            } else {
                DispatchQueue.main.async {
                    self.screenRecordingPermission = .denied
                }
                throw PermissionError.screenRecordingPermissionDenied
            }
        } catch {
            DispatchQueue.main.async {
                self.screenRecordingPermission = .denied
            }
            throw PermissionError.screenRecordingPermissionDenied
        }
    }
    
    func checkScreenRecordingPermission() {
        // Approche simplifiée : on considère que si l'app peut récupérer les displays,
        // alors la permission est probablement accordée. Sinon on reste en notDetermined
        // et on laisse l'utilisateur faire la demande explicite.
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                DispatchQueue.main.async {
                    if !content.displays.isEmpty {
                        // On a accès aux displays, c'est bon signe
                        self.screenRecordingPermission = .authorized
                    } else {
                        // Pas de displays trouvés, statut incertain
                        self.screenRecordingPermission = .notDetermined
                    }
                }
                
                print("📺 Screen recording check: Found \(content.displays.count) displays")
                
                // Debug: afficher les détails des displays
                for (index, display) in content.displays.enumerated() {
                    print("📺 Display \(index): width=\(display.width), height=\(display.height)")
                }
                
            } catch {
                print("📺 Screen recording check error: \(error)")
                
                // Analyser l'erreur pour déterminer le statut
                let errorString = error.localizedDescription.lowercased()
                
                DispatchQueue.main.async {
                    if errorString.contains("not authorized") || 
                       errorString.contains("denied") || 
                       errorString.contains("permission") {
                        self.screenRecordingPermission = .denied
                    } else {
                        // Pour toute autre erreur, on reste en notDetermined
                        self.screenRecordingPermission = .notDetermined
                    }
                }
            }
        }
    }
    
    
    // MARK: - Documents Folder Permission
    func requestDocumentsPermission() async throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        print("📁 [DOCUMENTS] Requesting Documents folder permission...")
        
        // Essayer d'accéder au dossier Documents avec le même nom de fichier réaliste
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let testFileURL = documentsURL.appendingPathComponent("meeting_\(timestamp)_permission_test.m4a")
        
        do {
            // Créer un fichier test avec le même type que l'app utilise
            let testData = Data()
            try testData.write(to: testFileURL)
            try FileManager.default.removeItem(at: testFileURL)
            
            print("📁 [DOCUMENTS] Permission test file created and removed successfully")
            
            await MainActor.run {
                self.documentsPermission = .authorized
                print("📁 [DOCUMENTS] Permission status updated to authorized")
            }
        } catch {
            print("📁 [DOCUMENTS] Permission test failed: \(error.localizedDescription)")
            
            await MainActor.run {
                self.documentsPermission = .denied
                print("📁 [DOCUMENTS] Permission status updated to denied")
            }
            throw PermissionError.documentsPermissionDenied
        }
    }
    
    func checkDocumentsPermission() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Tester avec le même pattern de nom de fichier que l'app utilise réellement
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let testFileURL = documentsURL.appendingPathComponent("meeting_\(timestamp)_test.m4a")
        
        print("📁 [DOCUMENTS] Testing write access with realistic filename: \(testFileURL.lastPathComponent)")
        print("📁 [DOCUMENTS] Full path: \(testFileURL.path)")
        
        do {
            // Tester l'écriture d'un fichier vide M4A (même type que l'app utilise)
            let testData = Data("test_audio_data".utf8)
            try testData.write(to: testFileURL)
            
            // Vérifier que le fichier existe réellement au bon endroit
            let realPath = testFileURL.path
            let fileExists = FileManager.default.fileExists(atPath: realPath)
            let isReadable = FileManager.default.isReadableFile(atPath: realPath)
            
            print("📁 [DOCUMENTS] File written, exists: \(fileExists), readable: \(isReadable)")
            
            if fileExists && isReadable {
                // Tenter de lire le fichier pour vérifier l'accès réel
                let readData = try Data(contentsOf: testFileURL)
                let readString = String(data: readData, encoding: .utf8) ?? ""
                
                if readString == "test_audio_data" {
                    print("📁 [DOCUMENTS] Real write/read test succeeded - genuine permission")
                    try? FileManager.default.removeItem(at: testFileURL)
                    documentsPermission = .authorized
                } else {
                    print("📁 [DOCUMENTS] Data mismatch - sandboxed/redirected write detected")
                    documentsPermission = .denied
                }
            } else {
                print("📁 [DOCUMENTS] File not accessible after write - permission denied")
                documentsPermission = .denied
            }
            
        } catch {
            print("📁 [DOCUMENTS] Write test failed: \(error.localizedDescription)")
            print("📁 [DOCUMENTS] Error code: \((error as NSError).code)")
            documentsPermission = .denied
        }
    }
    
    // MARK: - Accessibility Permission
    func requestAccessibilityPermission() async throws {
        print("🔓 [ACCESSIBILITY] Requesting Accessibility permission...")
        
        // Vérifier d'abord le statut actuel
        let currentStatus = checkAccessibilityPermissionStatus()
        
        if currentStatus == .authorized {
            DispatchQueue.main.async {
                self.accessibilityPermission = .authorized
            }
            return
        }
        
        // Si pas autorisé, ouvrir les préférences système
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        
        // L'utilisateur doit manuellement accorder la permission
        // On met à jour le statut comme "notDetermined" pour indiquer qu'une action est requise
        DispatchQueue.main.async {
            self.accessibilityPermission = .notDetermined
        }
        
        // Dans ce cas, on ne lance pas d'erreur car c'est un processus manuel
        // L'utilisateur peut vérifier manuellement plus tard
        print("🔓 [ACCESSIBILITY] System Preferences opened - user must manually grant permission")
    }
    
    func checkAccessibilityPermission() {
        print("🔓 [ACCESSIBILITY] === STARTING CHECK ===")
        let status = checkAccessibilityPermissionStatus()
        print("🔓 [ACCESSIBILITY] Status determined: \(status.displayName)")
        
        // Force UI update on main thread
        DispatchQueue.main.async {
            self.accessibilityPermission = status
            print("🔓 [ACCESSIBILITY] UI updated with status: \(status.displayName)")
        }
        
        print("🔓 [ACCESSIBILITY] === CHECK COMPLETE ===")
    }
    
    private func checkAccessibilityPermissionStatus() -> PermissionStatus {
        print("🔓 [ACCESSIBILITY] Checking permission status...")
        
        // Test 1: Basic check
        let basicCheck = AXIsProcessTrusted()
        print("🔓 [ACCESSIBILITY] Basic AXIsProcessTrusted: \(basicCheck)")
        
        // Test 2: Check with options (no prompt)
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)
        print("🔓 [ACCESSIBILITY] AXIsProcessTrustedWithOptions: \(accessEnabled)")
        
        // Test 3: Bundle identifier check
        if let bundleId = Bundle.main.bundleIdentifier {
            print("🔓 [ACCESSIBILITY] Bundle ID: \(bundleId)")
        } else {
            print("🔓 [ACCESSIBILITY] Bundle ID: NOT FOUND")
        }
        
        // Si les deux tests officiels passent, c'est suffisant
        // Le test simple `testSimpleAccessibilityAccess()` peut échouer même avec les permissions accordées
        if accessEnabled && basicCheck {
            print("🔓 [ACCESSIBILITY] → Status: AUTHORIZED (both official tests pass)")
            return .authorized
        } else {
            print("🔓 [ACCESSIBILITY] → Status: NOT_DETERMINED")
            return .notDetermined
        }
    }
    
    private func testSimpleAccessibilityAccess() -> Bool {
        // Test simple - juste essayer d'accéder à l'élément système
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedAppValue: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
        
        switch result {
        case .success:
            print("🔓 [ACCESSIBILITY] Simple test: SUCCESS - can access system elements")
            return true
        case .apiDisabled:
            print("🔓 [ACCESSIBILITY] Simple test: API_DISABLED")
            return false
        default:
            print("🔓 [ACCESSIBILITY] Simple test: ERROR - \(result.rawValue)")
            return false
        }
    }
    
    // MARK: - Request All Permissions
    func requestAllPermissions() async {
        do {
            try await requestMicrophonePermission()
            try await requestScreenRecordingPermission()
            try await requestDocumentsPermission()
            try await requestAccessibilityPermission()
        } catch {
            print("❌ Permission error: \(error)")
        }
        
        // Revérifier tous les statuts après les demandes
        checkAllPermissions()
    }
    
    // MARK: - Force Refresh All Permissions
    func refreshAllPermissions() {
        checkAllPermissions()
    }
    
    // MARK: - Computed Properties
    var allPermissionsGranted: Bool {
        return microphonePermission == .authorized &&
               screenRecordingPermission == .authorized &&
               documentsPermission == .authorized &&
               accessibilityPermission == .authorized
    }
    
    var recordingPermissionsGranted: Bool {
        return microphonePermission == .authorized &&
               screenRecordingPermission == .authorized &&
               documentsPermission == .authorized
    }
    
    var automaticDetectionPermissionsGranted: Bool {
        return accessibilityPermission == .authorized
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
        case .notDetermined: return "Non déterminé"
        case .authorized: return "Autorisé"
        case .denied: return "Refusé"
        case .restricted: return "Restreint"
        }
    }
    
    var color: NSColor {
        switch self {
        case .authorized: return .systemGreen
        case .denied, .restricted: return .systemRed
        case .notDetermined: return .systemOrange
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
            return "L'accès au microphone est requis pour enregistrer. Veuillez autoriser l'accès dans les Préférences Système."
        case .screenRecordingPermissionDenied:
            return "L'accès à l'enregistrement d'écran est requis pour capturer l'audio système. Veuillez autoriser l'accès dans les Préférences Système."
        case .documentsPermissionDenied:
            return "L'accès au dossier Documents est requis pour sauvegarder les enregistrements. Veuillez autoriser l'accès dans les Préférences Système."
        case .accessibilityPermissionDenied:
            return "L'accès à l'accessibilité est requis pour détecter automatiquement les réunions Teams. Veuillez autoriser l'accès dans les Préférences Système."
        }
    }
}