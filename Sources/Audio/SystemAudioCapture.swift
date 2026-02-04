import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 13.0, *)
final class SystemAudioCapture: NSObject {
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
        
        // Configuration du stream selon les recommandations Apple WWDC 2022
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        
        // Configuration audio officielle Apple : 48kHz, 2 canaux (WWDC 2022)
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        
        // Configuration vidéo minimale mais valide (nécessaire même pour audio seul)
        configuration.width = 100
        configuration.height = 100
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS max
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Créer un filtre de contenu simple et fiable (selon exemples Apple)
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "SystemAudioError", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        Logger.shared.log("🖥️ [SYSTEM_AUDIO] Using display: \(display.displayID) - \(display.width)x\(display.height)")
        
        // Filtrage simple : exclure seulement notre propre application pour éviter la boucle audio
        let excludedApps = availableContent.applications.filter { app in
            app.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        
        Logger.shared.log("🚫 [SYSTEM_AUDIO] Excluding \(excludedApps.count) applications (self)")
        
        // Filtre simple : tout capturer sauf notre app
        let filter = SCContentFilter(display: display, 
                                   excludingApplications: excludedApps, 
                                   exceptingWindows: [])
        
        // Préparer le fichier d'enregistrement
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("system_audio_\(Date().timeIntervalSince1970).wav")
        currentFileURL = audioFilename
        
        Logger.shared.log("🔊 [SYSTEM_AUDIO] Recording to: \(audioFilename.path)")
        
        // Créer et démarrer le stream avec validation
        do {
            stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            
            guard let stream = stream else {
                throw NSError(domain: "SystemAudioError", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream"])
            }
            
            Logger.shared.log("🎬 [SYSTEM_AUDIO] Stream created successfully")
            
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            Logger.shared.log("🔌 [SYSTEM_AUDIO] Audio output added to stream")
            
            try await stream.startCapture()
            Logger.shared.log("▶️ [SYSTEM_AUDIO] Stream capture started")
            
            isRecording = true
            recordingStartTime = Date()
            Logger.shared.log("✅ [SYSTEM_AUDIO] System audio recording started successfully")
            
        } catch {
            Logger.shared.log("❌ [SYSTEM_AUDIO] Stream creation/start failed: \(error)")
            
            // Diagnostic détaillé de l'erreur
            if let nsError = error as NSError? {
                Logger.shared.log("🔍 [SYSTEM_AUDIO] Error domain: \(nsError.domain)")
                Logger.shared.log("🔍 [SYSTEM_AUDIO] Error code: \(nsError.code)")
                Logger.shared.log("🔍 [SYSTEM_AUDIO] Error description: \(nsError.localizedDescription)")
                
                // Erreur -3812 spécifique
                if nsError.code == -3812 {
                    Logger.shared.log("🚨 [SYSTEM_AUDIO] Error -3812: Invalid parameter detected")
                    Logger.shared.log("💡 [SYSTEM_AUDIO] This may indicate hardware incompatibility or missing permissions")
                }
            }
            
            throw error
        }
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
        // Note: Ne pas appeler de méthodes async dans deinit car l'objet sera déjà désalloué
        // Le cleanup async doit être fait explicitement via stopRecording() avant de libérer l'objet
        if isRecording {
            Logger.shared.log("⚠️ [SYSTEM_AUDIO] deinit appelé pendant l'enregistrement - le fichier peut être incomplet")
            // Cleanup synchrone minimal
            stream = nil
            audioFile = nil
            isRecording = false
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
                    Logger.shared.log("🔊 System Audio: \(frameCount) frames @ \(description.mSampleRate)Hz, \(description.mChannelsPerFrame)ch")
                }
            }
        } catch {
            Logger.shared.log("❌ [SYSTEM_AUDIO] Audio processing error: \(error)")
        }
    }
} 