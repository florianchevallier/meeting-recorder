import Foundation
import AVFoundation

/// Mixer audio ultra-simple : mélange juste 2 pistes sans déformation
final class SimpleAudioMixer {
    private let outputFormat: AVAudioFormat
    private let bufferSize: AVAudioFrameCount = 1024
    
    // Callback pour recevoir l'audio mixé
    var onMixedAudio: ((AVAudioPCMBuffer) -> Void)?
    
    // Buffers temporaires pour chaque source
    private var systemAudioBuffer: AVAudioPCMBuffer?
    private var microphoneBuffer: AVAudioPCMBuffer?
    
    init() {
        // Format standard : 48kHz, stéréo, float32
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        ) else {
            fatalError("Impossible de créer le format audio")
        }
        self.outputFormat = format
        
        print("🎛️ SimpleAudioMixer initialisé (48kHz, stéréo)")
    }
    
    /// Traite l'audio système venant de ScreenCaptureKit
    func processSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let pcmBuffer = convertToStandardFormat(sampleBuffer) else {
            return
        }
        
        systemAudioBuffer = pcmBuffer
        tryMixAudio()
    }
    
    /// Traite l'audio microphone venant d'AVAudioEngine
    func processMicrophoneAudio(_ buffer: AVAudioPCMBuffer) {
        guard let convertedBuffer = convertToStandardFormat(buffer) else {
            return
        }
        
        microphoneBuffer = convertedBuffer
        tryMixAudio()
    }
    
    /// Mélange les deux pistes si elles sont disponibles
    private func tryMixAudio() {
        guard let systemBuffer = systemAudioBuffer,
              let micBuffer = microphoneBuffer else {
            return // Attend les deux sources
        }
        
        // Créer le buffer de sortie
        guard let mixedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: max(systemBuffer.frameLength, micBuffer.frameLength)
        ) else {
            return
        }
        
        let frameCount = min(systemBuffer.frameLength, micBuffer.frameLength)
        mixedBuffer.frameLength = frameCount
        
        // Mélange simple : addition des deux canaux avec volume réduit
        guard let systemData = systemBuffer.floatChannelData,
              let micData = micBuffer.floatChannelData,
              let mixedData = mixedBuffer.floatChannelData else {
            return
        }
        
        for channel in 0..<Int(outputFormat.channelCount) {
            let systemChannel = systemData[min(channel, Int(systemBuffer.format.channelCount) - 1)]
            let micChannel = micData[min(channel, Int(micBuffer.format.channelCount) - 1)]
            let mixedChannel = mixedData[channel]
            
            for frame in 0..<Int(frameCount) {
                // Mélange simple : 50% système + 50% micro
                let systemSample = systemChannel[frame] * 0.5
                let micSample = micChannel[frame] * 0.5
                mixedChannel[frame] = systemSample + micSample
            }
        }
        
        // Envoyer l'audio mixé
        onMixedAudio?(mixedBuffer)
        
        // Reset des buffers
        systemAudioBuffer = nil
        microphoneBuffer = nil
    }
    
    /// Convertit n'importe quel format vers notre format standard
    private func convertToStandardFormat(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        // Conversion CMSampleBuffer -> AVAudioPCMBuffer basique
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return nil
        }
        
        var mutableASBD = asbd
        guard let sourceFormat = AVAudioFormat(streamDescription: &mutableASBD) else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        // Copier les données
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
              let sourceChannelData = sourceBuffer.floatChannelData else {
            return nil
        }
        
        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer) == noErr,
              let data = dataPointer else {
            return nil
        }
        
        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Conversion simple selon le format source
        if sourceFormat.commonFormat == .pcmFormatFloat32 {
            let floatData = data.withMemoryRebound(to: Float.self, capacity: Int(frameCount) * Int(sourceFormat.channelCount)) { $0 }
            
            for channel in 0..<Int(sourceFormat.channelCount) {
                let channelBuffer = sourceChannelData[channel]
                for frame in 0..<Int(frameCount) {
                    channelBuffer[frame] = floatData[frame * Int(sourceFormat.channelCount) + channel]
                }
            }
        }
        
        // Conversion vers le format de sortie si nécessaire
        return convertToStandardFormat(sourceBuffer)
    }
    
    /// Convertit un AVAudioPCMBuffer vers notre format standard
    private func convertToStandardFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Si déjà au bon format, retourner tel quel
        if buffer.format.sampleRate == outputFormat.sampleRate &&
           buffer.format.channelCount == outputFormat.channelCount {
            return buffer
        }
        
        // Sinon, conversion basique (pour simplifier)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameLength) else {
            return nil
        }
        
        convertedBuffer.frameLength = buffer.frameLength
        
        guard let sourceData = buffer.floatChannelData,
              let destData = convertedBuffer.floatChannelData else {
            return nil
        }
        
        // Copie simple avec adaptation des canaux
        for channel in 0..<Int(outputFormat.channelCount) {
            let sourceChannel = sourceData[min(channel, Int(buffer.format.channelCount) - 1)]
            let destChannel = destData[channel]
            
            for frame in 0..<Int(buffer.frameLength) {
                destChannel[frame] = sourceChannel[frame]
            }
        }
        
        return convertedBuffer
    }
}