import SwiftUI
import EventKit
import AVFoundation
import ScreenCaptureKit

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var isRequesting = false
    
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    var microphoneStatus: PermissionStatus {
        permissionManager.microphonePermission
    }
    
    var screenRecordingStatus: PermissionStatus {
        permissionManager.screenRecordingPermission
    }
    
    var calendarStatus: PermissionStatus {
        permissionManager.calendarPermission
    }
    
    var documentsStatus: PermissionStatus {
        permissionManager.documentsPermission
    }
    
    var allPermissionsGranted: Bool {
        permissionManager.allPermissionsGranted
    }
    
    func checkCurrentPermissions() async {
        permissionManager.checkAllPermissions()
    }
    
    func requestAllPermissions() async {
        isRequesting = true
        await permissionManager.requestAllPermissions()
        // Petit délai pour laisser macOS mettre à jour les permissions
        try? await Task.sleep(for: .milliseconds(500))
        permissionManager.refreshAllPermissions()
        isRequesting = false
    }
    
    func requestMicrophonePermission() async {
        do {
            try await permissionManager.requestMicrophonePermission()
            // Rafraîchir après la demande
            try? await Task.sleep(for: .milliseconds(200))
            permissionManager.checkMicrophonePermission()
        } catch {
            print("❌ Microphone permission failed: \(error)")
        }
    }
    
    func requestScreenRecordingPermission() async {
        do {
            try await permissionManager.requestScreenRecordingPermission()
            // Rafraîchir après la demande
            try? await Task.sleep(for: .milliseconds(500))
            permissionManager.checkScreenRecordingPermission()
        } catch {
            print("❌ Screen recording permission failed: \(error)")
        }
    }
    
    func requestCalendarPermission() async {
        do {
            try await permissionManager.requestCalendarPermission()
            // Rafraîchir après la demande
            try? await Task.sleep(for: .milliseconds(200))
            permissionManager.checkCalendarPermission()
        } catch {
            print("❌ Calendar permission failed: \(error)")
        }
    }
    
    func requestDocumentsPermission() async {
        do {
            try await permissionManager.requestDocumentsPermission()
            // Rafraîchir après la demande
            try? await Task.sleep(for: .milliseconds(200))
            permissionManager.checkDocumentsPermission()
        } catch {
            print("❌ Documents permission failed: \(error)")
        }
    }
}