import SwiftUI

struct StatusBarMenu: View {
    @ObservedObject var statusBarManager: StatusBarManager
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Meeting Recorder")
                .font(.headline)
                .padding(.top, 8)
            
            HStack {
                Circle()
                    .fill(statusBarManager.isRecording ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusBarManager.isRecording ? "Recording" : "Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if statusBarManager.isRecording {
                        Text(formatDuration(statusBarManager.recordingDuration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: {
                if statusBarManager.isRecording {
                    statusBarManager.stopRecording()
                } else {
                    statusBarManager.startRecording()
                }
            }) {
                Text(statusBarManager.isRecording ? "Stop Recording" : "Start Recording")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 200)
        .overlay(
            Group {
                if let errorMessage = statusBarManager.errorMessage {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
            }
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}