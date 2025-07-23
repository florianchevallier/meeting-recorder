import Foundation
import AVFoundation

/// Mixer ultra-basique : pas de conversion, juste sauvegarde directe
final class UltraSimpleMixer {
    private var audioFile: AVAudioFile?
    
    init(outputURL: URL) throws {
        // Format fixe : 48kHz stéréo AAC
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        print("🎛️ UltraSimpleMixer: fichier créé à \(outputURL.lastPathComponent)")
    }
    
    /// Traite l'audio système - conversion directe sans resampling
    func processSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let pcmBuffer = convertCMSampleBufferDirectly(sampleBuffer) else {
            return
        }
        
        // Écrit directement dans le fichier (audio système seul pour le moment)
        writeToFile(pcmBuffer)
    }
    
    /// Traite l'audio microphone - pour l'instant on ignore pour éviter les problèmes
    func processMicrophoneAudio(_ buffer: AVAudioPCMBuffer) {
        // TODO: mélange simple plus tard
        // Pour l'instant, on sauvegarde que l'audio système pour débugger
    }
    
    /// Conversion directe CMSampleBuffer → AVAudioPCMBuffer sans changement de format
    private func convertCMSampleBufferDirectly(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            print("❌ Pas de format description")
            return nil
        }
        
        var mutableASBD = asbd
        guard let sourceFormat = AVAudioFormat(streamDescription: &mutableASBD) else {
            print("❌ Format source invalide")
            return nil
        }
        
        print("🔍 Format: \(sourceFormat.sampleRate)Hz, \(sourceFormat.channelCount)ch, \(sourceFormat.commonFormat.rawValue)")
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        // Créer le buffer dans le FORMAT EXACT du source
        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("❌ Impossible de créer le buffer")
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Copie directe des données
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer) == noErr,
              let data = dataPointer else {
            return nil
        }
        
        // Copie simple selon le format
        guard let channelData = buffer.floatChannelData else { return nil }
        
        if sourceFormat.commonFormat == .pcmFormatFloat32 {
            let floatData = data.withMemoryRebound(to: Float.self, capacity: Int(frameCount) * Int(sourceFormat.channelCount)) { $0 }
            
            // Copie interleaved → non-interleaved
            for channel in 0..<Int(sourceFormat.channelCount) {
                let channelBuffer = channelData[channel]
                for frame in 0..<Int(frameCount) {
                    channelBuffer[frame] = floatData[frame * Int(sourceFormat.channelCount) + channel]
                }
            }
        } else if sourceFormat.commonFormat == .pcmFormatInt16 {
            let intData = data.withMemoryRebound(to: Int16.self, capacity: Int(frameCount) * Int(sourceFormat.channelCount)) { $0 }
            
            for channel in 0..<Int(sourceFormat.channelCount) {
                let channelBuffer = channelData[channel]
                for frame in 0..<Int(frameCount) {
                    let sample = intData[frame * Int(sourceFormat.channelCount) + channel]
                    channelBuffer[frame] = Float(sample) / Float(Int16.max)
                }
            }
        } else {
            print("❌ Format non supporté: \(sourceFormat.commonFormat)")
            return nil
        }
        
        return buffer
    }
    
    private func writeToFile(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }
        
        do {
            try audioFile.write(from: buffer)
        } catch {
            print("❌ Erreur écriture: \(error)")
        }
    }
    
    func close() {
        audioFile = nil
        print("🎛️ UltraSimpleMixer fermé")
    }
}