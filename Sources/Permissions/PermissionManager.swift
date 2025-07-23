import Foundation
import SwiftUI
import AVFoundation
import EventKit
import ScreenCaptureKit

class PermissionManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var screenRecordingPermission: PermissionStatus = .notDetermined
    @Published var calendarPermission: PermissionStatus = .notDetermined
    @Published var documentsPermission: PermissionStatus = .notDetermined
    
    init() {
        checkAllPermissions()
    }
    
    // MARK: - Check All Permissions
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkScreenRecordingPermission()
        checkCalendarPermission()
        checkDocumentsPermission()
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
    
    // MARK: - Calendar Permission
    func requestCalendarPermission() async throws {
        let eventStore = EKEventStore()
        
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.calendarPermission = granted ? .authorized : .denied
        }
        
        if !granted {
            throw PermissionError.calendarPermissionDenied
        }
    }
    
    func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarPermission = PermissionStatus(from: status)
    }
    
    // MARK: - Documents Folder Permission
    func requestDocumentsPermission() async throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Essayer d'accéder au dossier Documents
        let granted = documentsURL.startAccessingSecurityScopedResource()
        if granted {
            documentsURL.stopAccessingSecurityScopedResource()
        }
        
        // Essayer de créer un fichier test
        let testFileURL = documentsURL.appendingPathComponent("meeting_recorder_test.txt")
        do {
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            
            DispatchQueue.main.async {
                self.documentsPermission = .authorized
            }
        } catch {
            DispatchQueue.main.async {
                self.documentsPermission = .denied
            }
            throw PermissionError.documentsPermissionDenied
        }
    }
    
    func checkDocumentsPermission() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testFileURL = documentsURL.appendingPathComponent("meeting_recorder_access_test.txt")
        
        do {
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: testFileURL)
            documentsPermission = .authorized
        } catch {
            documentsPermission = .denied
        }
    }
    
    // MARK: - Request All Permissions
    func requestAllPermissions() async {
        do {
            try await requestMicrophonePermission()
            try await requestScreenRecordingPermission()
            try await requestCalendarPermission()
            try await requestDocumentsPermission()
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
               calendarPermission == .authorized &&
               documentsPermission == .authorized
    }
    
    var recordingPermissionsGranted: Bool {
        return microphonePermission == .authorized &&
               screenRecordingPermission == .authorized &&
               documentsPermission == .authorized
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
    
    init(from ekStatus: EKAuthorizationStatus) {
        switch ekStatus {
        case .authorized, .fullAccess: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined, .writeOnly: self = .notDetermined
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
    case calendarPermissionDenied
    case documentsPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "L'accès au microphone est requis pour enregistrer. Veuillez autoriser l'accès dans les Préférences Système."
        case .screenRecordingPermissionDenied:
            return "L'accès à l'enregistrement d'écran est requis pour capturer l'audio système. Veuillez autoriser l'accès dans les Préférences Système."
        case .calendarPermissionDenied:
            return "L'accès au calendrier est requis pour démarrer automatiquement les enregistrements. Veuillez autoriser l'accès dans les Préférences Système."
        case .documentsPermissionDenied:
            return "L'accès au dossier Documents est requis pour sauvegarder les enregistrements. Veuillez autoriser l'accès dans les Préférences Système."
        }
    }
}