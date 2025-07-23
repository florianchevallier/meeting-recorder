import Foundation
import AVFoundation
import ScreenCaptureKit
import EventKit

class PermissionManager {
    
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
        
        if !granted {
            throw PermissionError.microphonePermissionDenied
        }
    }
    
    @available(macOS 12.3, *)
    func requestScreenRecordingPermission() async throws {
        let granted = await withCheckedContinuation { continuation in
            Task {
                do {
                    Logger.shared.log("📺 [SCREEN] Attempting to get shareable content...")
                    
                    // Use shared manager to avoid conflicts
                    let content = try await ShareableContentManager.shared.getShareableContent()
                    
                    Logger.shared.log("📺 [SCREEN] Found \(content.displays.count) displays")
                    Logger.shared.log("📺 [SCREEN] Found \(content.windows.count) windows")
                    
                    // If we can get shareable content, permissions are granted
                    let hasDisplays = !content.displays.isEmpty
                    Logger.shared.log("📺 [SCREEN] Permission check complete - has displays: \(hasDisplays)")
                    continuation.resume(returning: hasDisplays)
                } catch {
                    // If we get an error, it's likely due to missing permissions
                    Logger.shared.log("❌ [SCREEN] Screen recording permission check failed: \(error)")
                    Logger.shared.log("❌ [SCREEN] Error details: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
        
        Logger.shared.log("📺 [SCREEN] Permission check result: \(granted)")
        
        if !granted {
            throw PermissionError.screenRecordingPermissionDenied
        }
    }
    
    func requestCalendarPermission() async throws {
        let eventStore = EKEventStore()
        
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            return
        case .denied, .restricted:
            throw PermissionError.calendarPermissionDenied
        case .notDetermined, .writeOnly:
            let granted = await withCheckedContinuation { continuation in
                if #available(macOS 14.0, *) {
                    eventStore.requestFullAccessToEvents { granted, error in
                        continuation.resume(returning: granted)
                    }
                } else {
                    eventStore.requestAccess(to: .event) { granted, error in
                        continuation.resume(returning: granted)
                    }
                }
            }
            
            if !granted {
                throw PermissionError.calendarPermissionDenied
            }
        @unknown default:
            throw PermissionError.calendarPermissionDenied
        }
    }
    
    func requestAllPermissions() async throws {
        try await requestMicrophonePermission()
        
        if #available(macOS 12.3, *) {
            try await requestScreenRecordingPermission()
        }
        
        try await requestCalendarPermission()
    }
    
    @available(macOS 12.3, *)
    private func checkScreenRecordingPermission() async -> Bool {
        Logger.shared.log("🔍 [SCREEN] Checking screen recording permission...")
        
        do {
            let content = try await ShareableContentManager.shared.getShareableContent()
            let hasDisplays = !content.displays.isEmpty
            
            Logger.shared.log("🔍 [SCREEN] Check result: \(hasDisplays) (displays: \(content.displays.count))")
            
            return hasDisplays
        } catch {
            Logger.shared.log("❌ [SCREEN] Check failed with error: \(error)")
            return false
        }
    }
    
    func checkAllPermissions() async -> PermissionStatus {
        Logger.shared.log("🔍 [PERMISSIONS] Checking all permissions...")
        
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        
        let microphoneGranted = microphoneStatus == .authorized
        Logger.shared.log("🎤 [PERMISSIONS] Microphone: \(microphoneGranted) (status: \(microphoneStatus.rawValue))")
        
        let calendarGranted: Bool
        if #available(macOS 14.0, *) {
            calendarGranted = calendarStatus == .authorized || calendarStatus == .fullAccess
        } else {
            calendarGranted = calendarStatus == .authorized
        }
        Logger.shared.log("📅 [PERMISSIONS] Calendar: \(calendarGranted) (status: \(calendarStatus.rawValue))")
        
        // Check screen recording permission by trying to access shareable content
        let screenRecordingGranted: Bool
        if #available(macOS 12.3, *) {
            screenRecordingGranted = await checkScreenRecordingPermission()
        } else {
            screenRecordingGranted = true // Not available on older macOS
        }
        Logger.shared.log("📺 [PERMISSIONS] Screen Recording: \(screenRecordingGranted)")
        
        let finalStatus: PermissionStatus
        if microphoneGranted && calendarGranted && screenRecordingGranted {
            finalStatus = .allGranted
        } else if microphoneGranted || calendarGranted || screenRecordingGranted {
            finalStatus = .partiallyGranted
        } else {
            finalStatus = .denied
        }
        
        Logger.shared.log("📋 [PERMISSIONS] Final status: \(finalStatus)")
        return finalStatus
    }
}

enum PermissionError: Error, LocalizedError {
    case microphonePermissionDenied
    case screenRecordingPermissionDenied
    case calendarPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "L'accès au microphone est requis pour enregistrer vos réunions. Veuillez autoriser l'accès dans les Préférences Système."
        case .screenRecordingPermissionDenied:
            return "L'accès à l'enregistrement d'écran est requis pour capturer l'audio système. Veuillez autoriser l'accès dans les Préférences Système."
        case .calendarPermissionDenied:
            return "L'accès au calendrier est requis pour démarrer automatiquement les enregistrements. Veuillez autoriser l'accès dans les Préférences Système."
        }
    }
}

enum PermissionStatus {
    case allGranted
    case partiallyGranted
    case denied
}