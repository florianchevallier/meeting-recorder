import Foundation
import AVFoundation

class AudioMixer {
    
    static func mixAudioFiles(microphoneURL: URL?, systemAudioURL: URL?) async throws -> URL? {
        // Vérifier qu'au moins un fichier existe
        let hasMicrophoneFile = microphoneURL != nil && FileManager.default.fileExists(atPath: microphoneURL!.path)
        let hasSystemAudioFile = systemAudioURL != nil && FileManager.default.fileExists(atPath: systemAudioURL!.path)
        
        guard hasMicrophoneFile || hasSystemAudioFile else {
            Logger.shared.log("❌ [AUDIO_MIXER] Aucun fichier audio valide trouvé")
            return nil
        }
        
        Logger.shared.log("🎵 [AUDIO_MIXER] Début de la fusion audio...")
        
        // Créer le nom du fichier de sortie M4A
        let documentsPath = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "fr_FR")
        let timestamp = formatter.string(from: Date())
        let outputURL = documentsPath.appendingPathComponent("meeting_\(timestamp).m4a")
        
        // Configuration du format de sortie M4A (configuré automatiquement par AVAssetExportPresetAppleM4A)
        
        let composition = AVMutableComposition()
        
        // Track audio pour microphone (canal gauche principalement)
        if hasMicrophoneFile, let microphoneURL = microphoneURL {
            Logger.shared.log("🎤 [AUDIO_MIXER] Ajout piste microphone: \(microphoneURL.lastPathComponent)")
            try await addAudioTrack(from: microphoneURL, to: composition, channelLayout: .microphone)
        }
        
        // Track audio pour audio système (canal droit principalement)
        if hasSystemAudioFile, let systemAudioURL = systemAudioURL {
            Logger.shared.log("🔊 [AUDIO_MIXER] Ajout piste audio système: \(systemAudioURL.lastPathComponent)")
            try await addAudioTrack(from: systemAudioURL, to: composition, channelLayout: .system)
        }
        
        // Exporter la composition en M4A
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioMixerError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        Logger.shared.log("📦 [AUDIO_MIXER] Export vers: \(outputURL.lastPathComponent)")
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            Logger.shared.log("✅ [AUDIO_MIXER] Fusion terminée avec succès!")
            
            // Nettoyer les fichiers temporaires
            if let microphoneURL = microphoneURL {
                try? FileManager.default.removeItem(at: microphoneURL)
                Logger.shared.log("🗑️ [AUDIO_MIXER] Fichier microphone temporaire supprimé")
            }
            if let systemAudioURL = systemAudioURL {
                try? FileManager.default.removeItem(at: systemAudioURL)
                Logger.shared.log("🗑️ [AUDIO_MIXER] Fichier audio système temporaire supprimé")
            }
            
            return outputURL
        } else {
            Logger.shared.log("❌ [AUDIO_MIXER] Échec de l'export: \(exportSession.error?.localizedDescription ?? "Erreur inconnue")")
            throw AudioMixerError.exportFailed(exportSession.error)
        }
    }
    
    private static func addAudioTrack(from sourceURL: URL, to composition: AVMutableComposition, channelLayout: ChannelLayout) async throws {
        let asset = AVAsset(url: sourceURL)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            Logger.shared.log("⚠️ [AUDIO_MIXER] Aucune piste audio trouvée dans \(sourceURL.lastPathComponent)")
            return
        }
        
        let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        try compositionTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        Logger.shared.log("🎵 [AUDIO_MIXER] Piste ajoutée - Durée: \(CMTimeGetSeconds(duration))s")
    }
}

enum ChannelLayout {
    case microphone
    case system
}

enum AudioMixerError: Error, LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(Error?)
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Impossible de créer la session d'export audio"
        case .exportFailed(let error):
            return "Échec de l'export audio: \(error?.localizedDescription ?? "Erreur inconnue")"
        }
    }
} 