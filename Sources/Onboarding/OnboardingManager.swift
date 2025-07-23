import SwiftUI
import Combine

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var shouldShowOnboarding = false
    
    private let userDefaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let permissionManager = PermissionManager()
    
    private init() {
        let hasCompleted = userDefaults.bool(forKey: hasCompletedOnboardingKey)
        shouldShowOnboarding = !hasCompleted
    }
    
    func checkShouldShowOnboarding() {
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
        permissionManager.checkAllPermissions()
        
        // Si les permissions critiques ne sont pas accordées, montrer l'onboarding
        if !permissionManager.recordingPermissionsGranted {
            shouldShowOnboarding = true
        }
    }
}