import Foundation
import AVFoundation

final class AudioMixer {
    
    static func mixAudioFiles(microphoneURL: URL?, systemAudioURL: URL?) async throws -> URL? {
        // Verify that at least one file exists
        let hasMicrophoneFile = microphoneURL != nil && FileManager.default.fileExists(atPath: microphoneURL!.path)
        let hasSystemAudioFile = systemAudioURL != nil && FileManager.default.fileExists(atPath: systemAudioURL!.path)
        
        guard hasMicrophoneFile || hasSystemAudioFile else {
            Logger.shared.error("No valid audio files found", component: "AUDIO_MIXER")
            return nil
        }
        
        Logger.shared.info("Starting audio mixing...", component: "AUDIO_MIXER")

        // Create output M4A filename
        guard let documentsPath = FileSystemUtilities.getDocumentsDirectory() else {
            throw NSError(domain: "AudioMixerError", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }

        let filename = FileSystemUtilities.createTimestampedFilename(prefix: "meeting", extension: "m4a")
        let outputURL = documentsPath.appendingPathComponent(filename)

        // M4A output format configuration (automatically configured by AVAssetExportPresetAppleM4A)

        let composition = AVMutableComposition()

        // Audio track for microphone (primarily left channel)
        if hasMicrophoneFile, let microphoneURL = microphoneURL {
            Logger.shared.info("Adding microphone track: \(microphoneURL.lastPathComponent)", component: "AUDIO_MIXER")
            try await addAudioTrack(from: microphoneURL, to: composition)
        }

        // Audio track for system audio (primarily right channel)
        if hasSystemAudioFile, let systemAudioURL = systemAudioURL {
            Logger.shared.info("Adding system audio track: \(systemAudioURL.lastPathComponent)", component: "AUDIO_MIXER")
            try await addAudioTrack(from: systemAudioURL, to: composition)
        }
        
        // Exporter la composition en M4A
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioMixerError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        Logger.shared.info("Exporting to: \(outputURL.lastPathComponent)", component: "AUDIO_MIXER")
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            Logger.shared.info("Audio mixing completed successfully", component: "AUDIO_MIXER")
            
            // Clean up temporary files
            if let microphoneURL = microphoneURL {
                do {
                    try FileManager.default.removeItem(at: microphoneURL)
                    Logger.shared.debug("Temporary microphone file deleted", component: "AUDIO_MIXER")
                } catch {
                    Logger.shared.warning("Failed to delete temporary microphone file: \(error.localizedDescription)", component: "AUDIO_MIXER")
                }
            }
            if let systemAudioURL = systemAudioURL {
                do {
                    try FileManager.default.removeItem(at: systemAudioURL)
                    Logger.shared.debug("Temporary system audio file deleted", component: "AUDIO_MIXER")
                } catch {
                    Logger.shared.warning("Failed to delete temporary system audio file: \(error.localizedDescription)", component: "AUDIO_MIXER")
                }
            }
            
            return outputURL
        } else {
            let errorDescription = exportSession.error?.localizedDescription ?? "Unknown error"
            Logger.shared.error("Export failed: \(errorDescription)", component: "AUDIO_MIXER")
            throw AudioMixerError.exportFailed(exportSession.error)
        }
    }
    
    private static func addAudioTrack(from sourceURL: URL, to composition: AVMutableComposition) async throws {
        let asset = AVAsset(url: sourceURL)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            Logger.shared.warning("No audio track found in \(sourceURL.lastPathComponent)", component: "AUDIO_MIXER")
            return
        }
        
        let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        try compositionTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        Logger.shared.debug("Track added - Duration: \(CMTimeGetSeconds(duration))s", component: "AUDIO_MIXER")
    }
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