import Foundation
import AVFoundation
import ScreenCaptureKit

@MainActor
class AudioRecorder: ObservableObject {
    private var screenCapture: Any?
    private var microphoneCapture: MicrophoneCapture?
    private var ultraMixer: UltraSimpleMixer?
    private var currentRecordingURL: URL?
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    init() {
        // Initialization will be done in startRecording
    }
    
    func startRecording() async throws {
        guard !isRecording else { return }
        
        try await requestPermissions()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = DateFormatter.filenameDateFormatter.string(from: Date())
        let filename = "meeting_\(timestamp).m4a"
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        currentRecordingURL = fileURL
        
        // Setup ultra simple mixer (pas de conversion)
        do {
            ultraMixer = try UltraSimpleMixer(outputURL: fileURL)
        } catch {
            throw error
        }
        
        // Start microphone capture
        microphoneCapture = MicrophoneCapture()
        microphoneCapture?.delegate = self
        try microphoneCapture?.startCapture()
        
        // Start system audio capture - direct vers ultra mixer
        if #available(macOS 12.3, *) {
            let capture = MinimalScreenCapture()
            capture.onAudioReceived = { [weak self] sampleBuffer in
                Task { @MainActor in
                    self?.ultraMixer?.processSystemAudio(sampleBuffer)
                }
            }
            screenCapture = capture as Any
            try await capture.start()
        }
        
        startRecordingTimer()
        isRecording = true
        
        print("Recording started: \(filename)")
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        // Stop captures
        microphoneCapture?.stopCapture()
        
        if #available(macOS 12.3, *) {
            if let capture = screenCapture as? MinimalScreenCapture {
                await capture.stop()
            }
        }
        
        // Clean up
        ultraMixer?.close()
        ultraMixer = nil
        microphoneCapture = nil
        screenCapture = nil
        currentRecordingURL = nil
        
        stopRecordingTimer()
        isRecording = false
        recordingDuration = 0
        
        print("Recording stopped")
    }
    
    private func requestPermissions() async throws {
        let permissionManager = PermissionManager()
        
        try await permissionManager.requestMicrophonePermission()
        
        if #available(macOS 12.3, *) {
            try await permissionManager.requestScreenRecordingPermission()
        }
    }
    
    
    private func startRecordingTimer() {
        let startTime = Date()
        recordingStartTime = startTime
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
}


// MARK: - MicrophoneCaptureDelegate
extension AudioRecorder: MicrophoneCaptureDelegate {
    func microphoneCapture(_ capture: MicrophoneCapture, didReceiveAudioBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime) async {
        // Pour l'instant on ignore le micro pour debugger l'audio système
        // await MainActor.run {
        //     ultraMixer?.processMicrophoneAudio(buffer)
        // }
    }
}

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}