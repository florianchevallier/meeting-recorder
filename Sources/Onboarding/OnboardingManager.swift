import SwiftUI
import Combine

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var shouldShowOnboarding = false
    
    private let userDefaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    private init() {
        // Vérification immédiate sans Task async
        let hasCompleted = userDefaults.bool(forKey: hasCompletedOnboardingKey)
        shouldShowOnboarding = !hasCompleted
    }
    
    func checkShouldShowOnboarding() {
        // Vérification simple et immédiate
        let hasCompleted = userDefaults.bool(forKey: hasCompletedOnboardingKey)
        shouldShowOnboarding = !hasCompleted
    }
    
    func markOnboardingCompleted() {
        userDefaults.set(true, forKey: hasCompletedOnboardingKey)
        shouldShowOnboarding = false
    }
    
    func forceShowOnboarding() {
        shouldShowOnboarding = true
    }
    
    func recheckPermissions() {
        checkShouldShowOnboarding()
    }
    
    private func checkCriticalPermissions() async -> Bool {
        // Vérifier les permissions critiques (microphone + screen recording)
        let micStatus = await checkMicrophonePermission()
        let screenStatus = await checkScreenRecordingPermission()
        
        return micStatus != .granted || screenStatus != .granted
    }
    
    private func checkMicrophonePermission() async -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status.toPermissionStatus
    }
    
    private func checkScreenRecordingPermission() async -> PermissionStatus {
        // Vérification passive - ne déclenche PAS de demande de permission
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays.isEmpty ? .notDetermined : .granted
        } catch {
            let errorString = error.localizedDescription
            if errorString.contains("not authorized") || errorString.contains("denied") {
                return .denied
            } else {
                return .notDetermined
            }
        }
    }
}

import AVFoundation
import ScreenCaptureKit