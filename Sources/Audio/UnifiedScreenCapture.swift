import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 15.0, *)
class UnifiedScreenCapture: NSObject {
    private var stream: SCStream?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var outputURL: URL?
    
    // Queues dédiées pour chaque type de contenu
    private let screenQueue = DispatchQueue(label: "UnifiedCapture.ScreenQueue", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "UnifiedCapture.AudioQueue", qos: .userInitiated)
    private let microphoneQueue = DispatchQueue(label: "UnifiedCapture.MicrophoneQueue", qos: .userInitiated)
    
    // Configuration pour enregistrement direct
    private var recordingOutput: SCRecordingOutput?
    
    override init() {
        super.init()
    }
    
    /// Démarre l'enregistrement unifié avec sauvegarde directe en .mov
    func startDirectRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Already recording")
            return
        }
        
        Logger.shared.log("🚀 [UNIFIED_CAPTURE] Starting unified recording (macOS 15+)...")
        
        // Configuration du stream
        let configuration = SCStreamConfiguration()
        
        // Obtenir les dimensions réelles de l'écran
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "UnifiedCaptureError", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        // Configuration écran avec dimensions valides
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.showsCursor = true
        
        // Configuration audio système
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        
        // ✨ Configuration microphone (nouveau dans macOS 15+)
        configuration.captureMicrophone = true
        if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
            configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
            Logger.shared.log("🎤 [UNIFIED_CAPTURE] Using microphone: \(defaultMicrophone.localizedName)")
        }
        
        // Le contenu a déjà été récupéré plus haut
        
        // Fix pour macOS 15: utiliser includingApplications au lieu d'excludingWindows avec tableau vide
        let filter = SCContentFilter(display: display, 
                                   including: availableContent.applications, 
                                   exceptingWindows: [])
        
        // Préparer l'URL de sortie
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "meeting_unified_\(formatter.string(from: timestamp)).mov"
        outputURL = documentsPath.appendingPathComponent(filename)
        
        Logger.shared.log("🎬 [UNIFIED_CAPTURE] Recording to: \(filename)")
        
        // ✨ Configuration d'enregistrement direct
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = outputURL!
        recordingConfiguration.outputFileType = .mov
        recordingConfiguration.videoCodecType = .hevc
        // audioCodecType n'existe pas, le codec audio est géré automatiquement
        
        // Créer l'output d'enregistrement
        recordingOutput = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
        
        // Créer et configurer le stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        guard let stream = stream else {
            throw NSError(domain: "UnifiedCaptureError", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream - check screen recording permissions"])
        }
        
        // Ajouter l'output d'enregistrement au stream
        try stream.addRecordingOutput(recordingOutput!)
        
        // Démarrer la capture
        try await stream.startCapture()
        
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Unified recording started - Screen + System Audio + Microphone")
    }
    
    /// Démarre l'enregistrement unifié avec gestion manuelle des samples
    func startManualRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Already recording")
            return
        }
        
        Logger.shared.log("🚀 [UNIFIED_CAPTURE] Starting manual unified recording (macOS 15+)...")
        
        // Configuration identique mais sans SCRecordingOutput
        let configuration = SCStreamConfiguration()
        
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "UnifiedCaptureError", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = true
        
        if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
            configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
        }
        
        // Fix pour macOS 15: utiliser includingApplications au lieu d'excludingWindows avec tableau vide
        let filter = SCContentFilter(display: display, 
                                   including: availableContent.applications, 
                                   exceptingWindows: [])
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        guard let stream = stream else {
            throw NSError(domain: "UnifiedCaptureError", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream - check screen recording permissions"])
        }
        
        // Ajouter les outputs pour gestion manuelle
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: screenQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneQueue)
        
        try await stream.startCapture()
        
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Manual unified recording started")
    }
    
    func stopRecording() async -> URL? {
        guard isRecording, let stream = self.stream else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Not currently recording or stream is nil")
            return nil
        }
        
        Logger.shared.log("🛑 [UNIFIED_CAPTURE] Stopping unified recording...")
        
        do {
            // 1. D'abord, on demande au flux de s'arrêter et ON ATTEND que ce soit terminé
            try await stream.stopCapture()
            
            // 2. Une fois que la capture est VRAIMENT arrêtée, on peut retirer les outputs
            if let recordingOutput = self.recordingOutput {
                try stream.removeRecordingOutput(recordingOutput)
            }
            
        } catch {
            // On log l'erreur mais on continue le nettoyage
            Logger.shared.log("❌ [UNIFIED_CAPTURE] Error during stream stop/cleanup: \(error)")
        }
        
        // 3. Maintenant que tout est arrêté et nettoyé, on peut détruire les objets
        self.recordingOutput = nil
        self.stream = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.log("🎬 [UNIFIED_CAPTURE] Recording stopped. Duration: \(String(format: "%.1f", duration))s")
        }
        
        recordingStartTime = nil
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Unified recording stopped successfully")
        
        return outputURL
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Convertit un fichier MOV en M4A (audio uniquement)
    func convertMOVToM4A(sourceURL: URL) async throws -> URL {
        // Attendre un peu pour que le fichier soit complètement finalisé
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondes
        
        // Vérifier que le fichier existe et est lisible
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "ConversionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Fichier source introuvable : \(sourceURL.path)"])
        }
        
        let asset = AVURLAsset(url: sourceURL)
        
        // Attendre que l'asset soit chargé
        let duration = try await asset.load(.duration)
        Logger.shared.log("📹 [CONVERSION] Asset loaded, duration: \(CMTimeGetSeconds(duration))s")
        
        // Vérifier qu'il y a des pistes audio
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "ConversionError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Aucune piste audio trouvée dans le fichier"])
        }
        Logger.shared.log("🎵 [CONVERSION] Found \(audioTracks.count) audio track(s)")
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "ConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible de créer la session d'exportation."])
        }
        
        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension("m4a")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        Logger.shared.log("🔄 [CONVERSION] Starting export to: \(outputURL.lastPathComponent)")
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            Logger.shared.log("✅ [CONVERSION] Fichier converti avec succès en M4A : \(outputURL.lastPathComponent)")
            return outputURL
        case .failed:
            let errorDescription = exportSession.error?.localizedDescription ?? "Erreur inconnue"
            let errorCode = (exportSession.error as? NSError)?.code ?? -1
            Logger.shared.log("❌ [CONVERSION] Export failed with code \(errorCode): \(errorDescription)")
            throw exportSession.error ?? NSError(domain: "ConversionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "L'exportation a échoué avec une erreur inconnue."])
        case .cancelled:
            throw NSError(domain: "ConversionError", code: 3, userInfo: [NSLocalizedDescriptionKey: "L'exportation a été annulée."])
        default:
            throw NSError(domain: "ConversionError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Statut d'exportation inattendu: \(exportSession.status.rawValue)."])
        }
    }
    
    deinit {
        if isRecording {
            Task { [weak self] in
                await self?.stopRecording()
            }
        }
    }
}

// MARK: - SCStreamDelegate
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("❌ [UNIFIED_CAPTURE] Stream stopped with error: \(error)")
        isRecording = false
    }
}

// MARK: - SCRecordingOutputDelegate
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCRecordingOutputDelegate {
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Logger.shared.log("❌ [UNIFIED_CAPTURE] Recording output failed: \(error)")
        isRecording = false
    }
    
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Recording output finished successfully")
    }
}

// MARK: - SCStreamOutput (pour gestion manuelle si nécessaire)
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            handleScreenSample(sampleBuffer)
        case .audio:
            handleSystemAudioSample(sampleBuffer)
        case .microphone:
            handleMicrophoneSample(sampleBuffer)
        @unknown default:
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Unknown sample type received")
        }
    }
    
    private func handleScreenSample(_ sampleBuffer: CMSampleBuffer) {
        // On ignore les samples vidéo pour économiser les ressources
        // L'enregistrement est configuré pour produire une vidéo minimale
    }
    
    private func handleSystemAudioSample(_ sampleBuffer: CMSampleBuffer) {
        Logger.shared.log("🔊 [UNIFIED_CAPTURE] System audio sample received")
        // Le traitement audio est géré automatiquement par SCRecordingOutput
    }
    
    private func handleMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        Logger.shared.log("🎤 [UNIFIED_CAPTURE] Microphone sample received")
        // Le traitement audio est géré automatiquement par SCRecordingOutput
    }
}