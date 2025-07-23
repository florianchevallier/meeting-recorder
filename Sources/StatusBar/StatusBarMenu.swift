import SwiftUI

struct StatusBarMenu: View {
    @ObservedObject var statusBarManager: StatusBarManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🎤 Meeting Recorder")
                .font(.headline)
                .padding(.top, 8)
            
            Text("Micro + Audio Système")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(statusBarManager.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusBarManager.isRecording ? "Enregistrement actif" : "Prêt à enregistrer")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    if statusBarManager.isRecording {
                        Text(formatDuration(statusBarManager.recordingDuration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            Button(action: {
                if statusBarManager.isRecording {
                    statusBarManager.stopRecording()
                } else {
                    statusBarManager.startRecording()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: statusBarManager.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 14))
                    Text(statusBarManager.isRecording ? "Arrêter" : "Démarrer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(statusBarManager.isRecording ? .red : .blue)
            
            if let errorMessage = statusBarManager.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Divider()
            
            Button("Configurer Permissions") {
                statusBarManager.showOnboarding()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Quitter") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 200)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}