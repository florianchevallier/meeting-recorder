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
    private var audioFileFormat: AVAudioFormat?
    
    // Queue dédiée pour l'audio selon les pratiques officielles Apple
    private let audioQueue = DispatchQueue(label: "SystemAudio.AudioQueue", qos: .userInitiated)
    
    override init() {
        super.init()
    }
    
    func startRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [SYSTEM_AUDIO] Already recording")
            return
        }
        
        Logger.shared.log("🔍 [SYSTEM_AUDIO] Starting system audio capture...")
        
        // Configuration du stream selon les pratiques officielles
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        // Laisser ScreenCaptureKit gérer automatiquement sampleRate et channelCount
        // pour éviter les problèmes de distorsion
        
        // Créer un filtre de contenu pour capturer tout l'écran (nécessaire pour l'audio système)
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "SystemAudioError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Préparer le fichier d'enregistrement (sera créé avec le bon format lors du premier sample)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("system_audio_\(Date().timeIntervalSince1970).wav")
        currentFileURL = audioFilename
        
        Logger.shared.log("🔊 [SYSTEM_AUDIO] Recording to: \(audioFilename.path)")
        
        // Le fichier audio sera créé dynamiquement avec le format des données reçues
        
        // Créer et démarrer le stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try await stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
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
        audioFileFormat = nil
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
        
        // Vérifications robustes selon les pratiques officielles
        guard sampleBuffer.isValid,
              CMSampleBufferDataIsReady(sampleBuffer),
              CMSampleBufferGetNumSamples(sampleBuffer) > 0 else { 
            return 
        }
        
        // Méthode officielle Apple pour gérer l'audio ScreenCaptureKit
        handleAudioSample(sampleBuffer)
    }
    
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        do {
            // Utilisation de withAudioBufferList (approche officielle Apple)
            try sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
                      let description = formatDescription.audioStreamBasicDescription else {
                    Logger.shared.log("❌ [SYSTEM_AUDIO] Invalid audio format description")
                    return
                }
                
                let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
                let format = AVAudioFormat(standardFormatWithSampleRate: description.mSampleRate, 
                                         channels: description.mChannelsPerFrame)!
                
                // Créer le fichier audio dynamiquement avec le format réel des données
                if audioFile == nil {
                    guard let fileURL = currentFileURL else {
                        Logger.shared.log("❌ [SYSTEM_AUDIO] No file URL available")
                        return
                    }
                    
                    audioFileFormat = format
                    audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
                    Logger.shared.log("✅ [SYSTEM_AUDIO] Audio file created with format: \(description.mSampleRate)Hz, \(description.mChannelsPerFrame)ch")
                }
                
                guard let audioFile = audioFile else {
                    Logger.shared.log("❌ [SYSTEM_AUDIO] Audio file not available")
                    return
                }
                
                // Utiliser bufferListNoCopy pour éviter les distorsions de CMSampleBufferCopyPCMDataIntoAudioBufferList
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                                       bufferListNoCopy: audioBufferList.unsafePointer) else {
                    Logger.shared.log("❌ [SYSTEM_AUDIO] Failed to create PCM buffer with bufferListNoCopy")
                    return
                }
                
                audioBuffer.frameLength = AVAudioFrameCount(frameCount)
                
                // Écriture directe sans copie supplémentaire (évite la distorsion)
                try audioFile.write(from: audioBuffer)
                
                // Log périodique pour diagnostic
                if frameCount > 0 {
                    print("🔊 System Audio: \(frameCount) frames @ \(description.mSampleRate)Hz, \(description.mChannelsPerFrame)ch")
                }
            }
        } catch {
            Logger.shared.log("❌ [SYSTEM_AUDIO] Audio processing error: \(error)")
        }
    }
} 