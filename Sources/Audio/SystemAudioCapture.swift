import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 13.0, *)
class SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var currentFileURL: URL?
    
    override init() {
        super.init()
    }
    
    func startRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [SYSTEM_AUDIO] Already recording")
            return
        }
        
        Logger.shared.log("🔍 [SYSTEM_AUDIO] Starting system audio capture...")
        
        // Configuration du stream
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        
        // Créer un filtre de contenu pour capturer tout l'écran (nécessaire pour l'audio système)
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "SystemAudioError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Créer le fichier d'enregistrement
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("system_audio_\(Date().timeIntervalSince1970).wav")
        currentFileURL = audioFilename
        
        Logger.shared.log("🔊 [SYSTEM_AUDIO] Recording to: \(audioFilename.path)")
        
        // Configuration du format audio
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        audioFile = try AVAudioFile(forWriting: audioFilename, settings: audioFormat.settings)
        
        // Créer et démarrer le stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try await stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
        try await stream?.startCapture()
        
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.log("✅ [SYSTEM_AUDIO] System audio recording started successfully")
    }
    
    func stopRecording() async -> URL? {
        guard isRecording else {
            Logger.shared.log("⚠️ [SYSTEM_AUDIO] Not currently recording")
            return nil
        }
        
        do {
            try await stream?.stopCapture()
        } catch {
            Logger.shared.log("❌ [SYSTEM_AUDIO] Error stopping stream: \(error)")
        }
        
        stream = nil
        audioFile = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.log("🎬 [SYSTEM_AUDIO] Recording stopped. Duration: \(String(format: "%.1f", duration))s")
        }
        
        recordingStartTime = nil
        Logger.shared.log("✅ [SYSTEM_AUDIO] System audio recording stopped successfully")
        
        return currentFileURL
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    deinit {
        if isRecording {
            Task {
                await stopRecording()
            }
        }
    }
}

// MARK: - SCStreamDelegate
@available(macOS 13.0, *)
extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("❌ [SYSTEM_AUDIO] Stream stopped with error: \(error)")
        isRecording = false
    }
}

// MARK: - SCStreamOutput
@available(macOS 13.0, *)
extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Convertir et sauvegarder les données audio
        guard let audioFile = audioFile else { return }
        
        do {
            // Convertir le CMSampleBuffer en AVAudioPCMBuffer
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
            }
            
            let audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            
            let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else {
                return
            }
            
            audioBuffer.frameLength = AVAudioFrameCount(sampleCount)
            
            // Copier les données audio
            let audioBufferList = audioBuffer.mutableAudioBufferList
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(sampleCount), into: audioBufferList)
            
            // Écrire dans le fichier
            try audioFile.write(from: audioBuffer)
            
            // Log périodique
            let bufferFrameCount = audioBuffer.frameLength
            let channels = audioBuffer.format.channelCount
            print("🔊 System Audio: \(bufferFrameCount) frames, \(channels) channels")
            
        } catch {
            Logger.shared.log("❌ [SYSTEM_AUDIO] Failed to write audio: \(error)")
        }
    }
} 