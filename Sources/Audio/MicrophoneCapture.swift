import Foundation
import AVFoundation

final class SimpleMicrophoneRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var currentFileURL: URL?
    
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
            Logger.shared.warning("Already recording", component: "AUDIO")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create recording file
        guard let documentsPath = FileSystemUtilities.getDocumentsDirectory() else {
            Logger.shared.error("Documents directory unavailable", component: "AUDIO")
            throw NSError(domain: "MicrophoneError", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }

        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        currentFileURL = audioFilename

        Logger.shared.info("Recording to: \(audioFilename.path)", component: "AUDIO")
        
        do {
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: inputFormat.settings)
        } catch {
            Logger.shared.error("Failed to create audio file: \(error)", component: "AUDIO")
            throw error
        }
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: Constants.Audio.bufferSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
                
                // Throttled log for audio data (high frequency)
                Logger.shared.logThrottled(
                    "Recording: \(buffer.frameLength) frames, \(buffer.format.channelCount) channels",
                    level: .debug,
                    component: "AUDIO",
                    throttleInterval: 5.0,
                    throttleKey: "mic_buffer_log"
                )
                
            } catch {
                Logger.shared.error("Failed to write audio: \(error)", component: "AUDIO")
            }
        }
        
        try audioEngine.start()
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.info("Recording started successfully", component: "AUDIO")
    }
    
    func stopRecording() -> URL? {
        guard isRecording else {
            Logger.shared.warning("Not currently recording", component: "AUDIO")
            return nil
        }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.info("Recording stopped. Duration: \(String(format: "%.1f", duration))s", component: "AUDIO")
        }
        
        recordingStartTime = nil
        Logger.shared.info("Recording stopped successfully", component: "AUDIO")
        
        return currentFileURL
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    deinit {
        if isRecording {
            _ = stopRecording()
        }
    }
}