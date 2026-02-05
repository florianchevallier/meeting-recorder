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
            Logger.shared.warning("Already recording", component: "SYSTEM_AUDIO")
            return
        }
        
        Logger.shared.info("Starting system audio capture...", component: "SYSTEM_AUDIO")
        
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
        
        Logger.shared.debug("Using display: \(display.displayID) - \(display.width)x\(display.height)", component: "SYSTEM_AUDIO")
        
        // Filtrage simple : exclure seulement notre propre application pour éviter la boucle audio
        let excludedApps = availableContent.applications.filter { app in
            app.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        
        Logger.shared.debug("Excluding \(excludedApps.count) applications (self)", component: "SYSTEM_AUDIO")
        
        // Filtre simple : tout capturer sauf notre app
        let filter = SCContentFilter(display: display, 
                                   excludingApplications: excludedApps, 
                                   exceptingWindows: [])
        
        // Prepare recording file
        guard let documentsPath = FileSystemUtilities.getDocumentsDirectory() else {
            throw NSError(domain: "SystemAudioError", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }

        let audioFilename = documentsPath.appendingPathComponent("system_audio_\(Date().timeIntervalSince1970).wav")
        currentFileURL = audioFilename

        Logger.shared.info("Recording to: \(audioFilename.path)", component: "SYSTEM_AUDIO")
        
        // Créer et démarrer le stream avec validation
        do {
            stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            
            guard let stream = stream else {
                throw NSError(domain: "SystemAudioError", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream"])
            }
            
            Logger.shared.debug("Stream created successfully", component: "SYSTEM_AUDIO")
            
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            Logger.shared.debug("Audio output added to stream", component: "SYSTEM_AUDIO")
            
            try await stream.startCapture()
            Logger.shared.debug("Stream capture started", component: "SYSTEM_AUDIO")
            
            isRecording = true
            recordingStartTime = Date()
            Logger.shared.info("System audio recording started successfully", component: "SYSTEM_AUDIO")
            
        } catch {
            Logger.shared.error("Stream creation/start failed: \(error)", component: "SYSTEM_AUDIO")
            
            // Diagnostic détaillé de l'erreur
            if let nsError = error as NSError? {
                Logger.shared.debug("Error domain: \(nsError.domain)", component: "SYSTEM_AUDIO")
                Logger.shared.debug("Error code: \(nsError.code)", component: "SYSTEM_AUDIO")
                Logger.shared.debug("Error description: \(nsError.localizedDescription)", component: "SYSTEM_AUDIO")
                
                // Erreur -3812 spécifique
                if nsError.code == -3812 {
                    Logger.shared.warning("Error -3812: Invalid parameter detected - may indicate hardware incompatibility or missing permissions", component: "SYSTEM_AUDIO")
                }
            }
            
            throw error
        }
    }
    
    func stopRecording() async -> URL? {
        guard isRecording else {
            Logger.shared.warning("Not currently recording", component: "SYSTEM_AUDIO")
            return nil
        }
        
        do {
            try await stream?.stopCapture()
        } catch {
            Logger.shared.error("Error stopping stream: \(error)", component: "SYSTEM_AUDIO")
        }
        
        stream = nil
        audioFile = nil
        audioFileFormat = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.info("Recording stopped. Duration: \(String(format: "%.1f", duration))s", component: "SYSTEM_AUDIO")
        }
        
        recordingStartTime = nil
        Logger.shared.info("System audio recording stopped successfully", component: "SYSTEM_AUDIO")
        
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
            Logger.shared.warning("deinit called during recording - file may be incomplete", component: "SYSTEM_AUDIO")
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
        Logger.shared.error("Stream stopped with error: \(error)", component: "SYSTEM_AUDIO")
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
                    Logger.shared.error("Invalid audio format description", component: "SYSTEM_AUDIO")
                    return
                }
                
                let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
                let format = AVAudioFormat(standardFormatWithSampleRate: description.mSampleRate, 
                                         channels: description.mChannelsPerFrame)!
                
                // Créer le fichier audio dynamiquement avec le format réel des données
                if audioFile == nil {
                    guard let fileURL = currentFileURL else {
                        Logger.shared.error("No file URL available", component: "SYSTEM_AUDIO")
                        return
                    }
                    
                    audioFileFormat = format
                    audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
                    Logger.shared.info("Audio file created with format: \(description.mSampleRate)Hz, \(description.mChannelsPerFrame)ch", component: "SYSTEM_AUDIO")
                }
                
                guard let audioFile = audioFile else {
                    Logger.shared.error("Audio file not available", component: "SYSTEM_AUDIO")
                    return
                }
                
                // Utiliser bufferListNoCopy pour éviter les distorsions de CMSampleBufferCopyPCMDataIntoAudioBufferList
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                                       bufferListNoCopy: audioBufferList.unsafePointer) else {
                    Logger.shared.error("Failed to create PCM buffer with bufferListNoCopy", component: "SYSTEM_AUDIO")
                    return
                }
                
                audioBuffer.frameLength = AVAudioFrameCount(frameCount)
                
                // Écriture directe sans copie supplémentaire (évite la distorsion)
                try audioFile.write(from: audioBuffer)
                
                // Throttled log for audio data (high frequency)
                Logger.shared.logThrottled(
                    "System Audio: \(frameCount) frames @ \(description.mSampleRate)Hz, \(description.mChannelsPerFrame)ch",
                    level: .debug,
                    component: "SYSTEM_AUDIO",
                    throttleInterval: 5.0,
                    throttleKey: "system_audio_buffer_log"
                )
            }
        } catch {
            Logger.shared.error("Audio processing error: \(error)", component: "SYSTEM_AUDIO")
        }
    }
} 