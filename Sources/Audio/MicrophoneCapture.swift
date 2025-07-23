import Foundation
import AVFoundation

class SimpleMicrophoneRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }
    
    func startRecording() throws {
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "AudioError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
        }
        
        guard !isRecording else {
            Logger.shared.log("⚠️ [AUDIO] Already recording")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create recording file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        Logger.shared.log("🎤 [AUDIO] Recording to: \(audioFilename.path)")
        
        do {
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: inputFormat.settings)
        } catch {
            Logger.shared.log("❌ [AUDIO] Failed to create audio file: \(error)")
            throw error
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
                
                // Log audio data received
                let frameCount = buffer.frameLength
                let channels = buffer.format.channelCount
                print("🎤 Recording: \(frameCount) frames, \(channels) channels")
                
            } catch {
                Logger.shared.log("❌ [AUDIO] Failed to write audio: \(error)")
            }
        }
        
        try audioEngine.start()
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.log("✅ [AUDIO] Recording started successfully")
    }
    
    func stopRecording() {
        guard isRecording else {
            Logger.shared.log("⚠️ [AUDIO] Not currently recording")
            return
        }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.log("🎬 [AUDIO] Recording stopped. Duration: \(String(format: "%.1f", duration))s")
        }
        
        recordingStartTime = nil
        Logger.shared.log("✅ [AUDIO] Recording stopped successfully")
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    deinit {
        if isRecording {
            stopRecording()
        }
    }
}