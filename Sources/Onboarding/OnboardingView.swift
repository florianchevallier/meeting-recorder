import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Meeting Recorder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enregistrez automatiquement vos réunions avec l'audio système et votre microphone")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Permissions list
            VStack(spacing: 20) {
                PermissionRow(
                    title: "Accès au Microphone",
                    description: "Pour enregistrer votre voix durant les réunions",
                    icon: "mic.fill",
                    status: viewModel.microphoneStatus,
                    action: { await viewModel.requestMicrophonePermission() }
                )
                
                PermissionRow(
                    title: "Enregistrement d'Écran",
                    description: "Pour capturer l'audio système (Zoom, Teams, etc.)",
                    icon: "display",
                    status: viewModel.screenRecordingStatus,
                    action: { await viewModel.requestScreenRecordingPermission() }
                )
                
                
                PermissionRow(
                    title: "Accès aux Documents",
                    description: "Pour sauvegarder vos enregistrements",
                    icon: "folder",
                    status: viewModel.documentsStatus,
                    action: { await viewModel.requestDocumentsPermission() }
                )
                
                PermissionRow(
                    title: "Accès à l'Accessibilité",
                    description: "Pour détecter automatiquement les réunions Teams",
                    icon: "accessibility",
                    status: viewModel.accessibilityStatus,
                    action: { await viewModel.requestAccessibilityPermission() }
                )
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                if viewModel.allPermissionsGranted {
                    Button("Commencer à Utiliser") {
                        onboardingManager.markOnboardingCompleted()
                        closeWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Demander Toutes les Permissions") {
                        Task {
                            await viewModel.requestAllPermissions()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isRequesting)
                }
                
                Button("Actualiser les Permissions") {
                    Task {
                        await viewModel.checkCurrentPermissions()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Passer (Configurer Plus Tard)") {
                    onboardingManager.markOnboardingCompleted()
                    closeWindow()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
        .task {
            await viewModel.checkCurrentPermissions()
            // Demander automatiquement toutes les permissions au premier lancement
            await viewModel.requestAllPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Quand l'app devient active (ex: retour depuis les Préférences Système)
            Task {
                await viewModel.checkCurrentPermissions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in
            // Quand l'app sort du mode caché
            Task {
                await viewModel.checkCurrentPermissions()
            }
        }
    }
    
    private func closeWindow() {
        // Fermer la fenêtre actuelle de manière sûre
        if let window = NSApp.keyWindow {
            window.close()
        } else if let window = NSApp.windows.first(where: { $0.title.contains("Configuration des Permissions") }) {
            window.close()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionStatus
    let action: () async -> Void
    
    @State private var isRequesting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(status.swiftUIColor)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status/Action
            Group {
                switch status {
                case .authorized:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                        
                case .denied, .restricted:
                    Button("Ouvrir Préférences") {
                        openSystemPreferences()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                case .notDetermined:
                    Button("Autoriser") {
                        isRequesting = true
                        Task {
                            await action()
                            isRequesting = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRequesting)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}


#Preview {
    OnboardingView()
}