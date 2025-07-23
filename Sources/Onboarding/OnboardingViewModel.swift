import SwiftUI
import EventKit
import AVFoundation
import ScreenCaptureKit

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .unknown
    @Published var screenRecordingStatus: PermissionStatus = .unknown
    @Published var calendarStatus: PermissionStatus = .unknown
    @Published var isRequesting = false
    
    private let permissionManager = PermissionManager()
    private let eventStore = EKEventStore()
    
    var allPermissionsGranted: Bool {
        microphoneStatus == .granted && 
        screenRecordingStatus == .granted && 
        calendarStatus == .granted
    }
    
    func checkCurrentPermissions() async {
        await checkMicrophonePermission()
        await checkScreenRecordingPermission()
        await checkCalendarPermission()
    }
    
    func requestAllPermissions() async {
        isRequesting = true
        
        await requestMicrophonePermission()
        await requestScreenRecordingPermission()
        await requestCalendarPermission()
        
        isRequesting = false
    }
    
    // MARK: - Microphone
    
    func checkMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneStatus = status.toPermissionStatus
    }
    
    func requestMicrophonePermission() async {
        guard microphoneStatus != .granted else { return }
        
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = granted ? .granted : .denied
    }
    
    // MARK: - Screen Recording
    
    func checkScreenRecordingPermission() async {
        // Vérification passive sans déclencher de demande
        // On regarde si on peut accéder au contenu partageable sans créer de stream
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // Si on peut récupérer des displays, la permission est accordée
            screenRecordingStatus = content.displays.isEmpty ? .notDetermined : .granted
        } catch {
            // Si on ne peut pas accéder au contenu, soit pas de permission, soit pas déterminé
            let errorString = error.localizedDescription
            if errorString.contains("not authorized") || errorString.contains("denied") {
                screenRecordingStatus = .denied
            } else {
                screenRecordingStatus = .notDetermined
            }
        }
    }
    
    func requestScreenRecordingPermission() async {
        guard screenRecordingStatus != .granted else { return }
        
        // Pour demander la permission, on essaie de créer un stream temporaire
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.width = 1
                config.height = 1
                
                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
                
                try await stream.startCapture()
                try await stream.stopCapture()
                
                screenRecordingStatus = .granted
            }
        } catch {
            screenRecordingStatus = .denied
        }
    }
    
    // MARK: - Calendar
    
    func checkCalendarPermission() async {
        if #available(macOS 14.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess:
                calendarStatus = .granted
            case .writeOnly:
                calendarStatus = .denied // On a besoin du full access
            case .denied:
                calendarStatus = .denied
            case .notDetermined:
                calendarStatus = .notDetermined
            case .restricted:
                calendarStatus = .denied
            @unknown default:
                calendarStatus = .unknown
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .authorized:
                calendarStatus = .granted
            case .denied:
                calendarStatus = .denied
            case .notDetermined:
                calendarStatus = .notDetermined
            case .restricted:
                calendarStatus = .denied
            case .fullAccess:
                calendarStatus = .granted
            case .writeOnly:
                calendarStatus = .denied
            @unknown default:
                calendarStatus = .unknown
            }
        }
    }
    
    func requestCalendarPermission() async {
        guard calendarStatus != .granted else { return }
        
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                calendarStatus = granted ? .granted : .denied
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                calendarStatus = granted ? .granted : .denied
            }
        } catch {
            print("Erreur lors de la demande de permission calendrier: \(error)")
            calendarStatus = .denied
        }
    }
}

// MARK: - Extensions

extension AVAuthorizationStatus {
    var toPermissionStatus: PermissionStatus {
        switch self {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .denied
        @unknown default:
            return .unknown
        }
    }
}