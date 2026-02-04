import SwiftUI
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isRequesting = false
    
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published var documentsStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    
    @Published var allPermissionsGranted: Bool = false
    
    private var permissionManager = PermissionManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // S'abonner aux changements de permissions du manager
        // Note: Utiliser .sink avec [weak self] au lieu de .assign pour éviter les cycles de rétention
        permissionManager.$microphonePermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.microphoneStatus = status
            }
            .store(in: &cancellables)

        permissionManager.$screenRecordingPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.screenRecordingStatus = status
            }
            .store(in: &cancellables)

        permissionManager.$documentsPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.documentsStatus = status
            }
            .store(in: &cancellables)

        permissionManager.$accessibilityPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.accessibilityStatus = status
            }
            .store(in: &cancellables)

        // S'abonner à tous les changements pour mettre à jour `allPermissionsGranted`
        $microphoneStatus.merge(with: $screenRecordingStatus, $documentsStatus, $accessibilityStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAllPermissionsGranted()
            }
            .store(in: &cancellables)

        // Vérifier l'état initial
        checkCurrentPermissions()
    }
    
    private func updateAllPermissionsGranted() {
        allPermissionsGranted = permissionManager.allPermissionsGranted
    }
    
    func checkCurrentPermissions() {
        permissionManager.checkAllPermissions()
    }
    
    func requestAllPermissions() async {
        isRequesting = true
        await permissionManager.requestAllPermissions()
        isRequesting = false
    }
    
    func requestMicrophonePermission() async {
        await permissionManager.requestMicrophonePermission()
    }
    
    func requestScreenRecordingPermission() async {
        await permissionManager.requestScreenRecordingPermission()
    }
    
    func requestDocumentsPermission() async {
        await permissionManager.requestDocumentsPermission()
    }
    
    func requestAccessibilityPermission() async {
        await permissionManager.requestAccessibilityPermission()
    }
}