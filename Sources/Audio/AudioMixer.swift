import Foundation
import AVFoundation
import ScreenCaptureKit

protocol AudioMixerDelegate: AnyObject {
    func audioMixer(_ mixer: AudioMixer, didProduceMixedAudioBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime) async
}

class AudioMixer: NSObject {
    weak var delegate: AudioMixerDelegate?
    
    private var audioEngine: AVAudioEngine
    private var mixerNode: AVAudioMixerNode
    private var systemAudioPlayerNode: AVAudioPlayerNode
    private var microphoneInputNode: AVAudioInputNode
    
    private let commonFormat: AVAudioFormat
    private let bufferSize: AVAudioFrameCount = 1024
    
    private var isRunning = false
    
    override init() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        systemAudioPlayerNode = AVAudioPlayerNode()
        microphoneInputNode = audioEngine.inputNode
        
        // Create common format for mixing
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 48000,
                                       channels: 2,
                                       interleaved: false) else {
            fatalError("Unable to create audio format")
        }
        commonFormat = format
        
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        // Attach nodes to the engine
        audioEngine.attach(mixerNode)
        audioEngine.attach(systemAudioPlayerNode)
        
        // Connect system audio player to mixer
        audioEngine.connect(systemAudioPlayerNode, to: mixerNode, format: commonFormat)
        
        // Connect microphone input to mixer with format conversion if needed
        let microphoneFormat = microphoneInputNode.outputFormat(forBus: 0)
        audioEngine.connect(microphoneInputNode, to: mixerNode, format: microphoneFormat)
        
        // Connect mixer to output (but we won't actually play it)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: commonFormat)
        
        // Install tap on mixer to capture mixed audio
        mixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: commonFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            Task {
                await self.delegate?.audioMixer(self, didProduceMixedAudioBuffer: buffer, at: time)
            }
        }
    }
    
    func startMixing() throws {
        guard !isRunning else { return }
        
        try audioEngine.start()
        systemAudioPlayerNode.play()
        isRunning = true
    }
    
    func stopMixing() {
        guard isRunning else { return }
        
        systemAudioPlayerNode.stop()
        audioEngine.stop()
        isRunning = false
    }
    
    func processSystemAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let audioBuffer = convertCMSampleBufferToAVAudioPCMBuffer(sampleBuffer) else {
            return
        }
        
        // Schedule the buffer to play through the system audio player node
        systemAudioPlayerNode.scheduleBuffer(audioBuffer, completionHandler: nil)
    }
    
    private func convertCMSampleBufferToAVAudioPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        
        guard let asbd = asbd else { return nil }
        var mutableASBD = asbd
        guard let format = AVAudioFormat(streamDescription: &mutableASBD) else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        // Copy audio data from CMSampleBuffer to AVAudioPCMBuffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer)
        
        guard status == noErr,
              let dataPointer = dataPointer,
              let channelData = buffer.floatChannelData else {
            return nil
        }
        
        let channelCount = Int(format.channelCount)
        let frameLength = Int(frameCount)
        
        // Convert based on the original format
        if format.commonFormat == AVAudioCommonFormat.pcmFormatFloat32 {
            let sourceData = dataPointer.withMemoryRebound(to: Float.self, capacity: frameLength * channelCount) { $0 }
            
            for channel in 0..<channelCount {
                let channelBuffer = channelData[channel]
                for frame in 0..<frameLength {
                    channelBuffer[frame] = sourceData[frame * channelCount + channel]
                }
            }
        } else if format.commonFormat == AVAudioCommonFormat.pcmFormatInt16 {
            let sourceData = dataPointer.withMemoryRebound(to: Int16.self, capacity: frameLength * channelCount) { $0 }
            
            for channel in 0..<channelCount {
                let channelBuffer = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = sourceData[frame * channelCount + channel]
                    channelBuffer[frame] = Float(sample) / Float(Int16.max)
                }
            }
        }
        
        buffer.frameLength = AVAudioFrameCount(frameLength)
        return buffer
    }
    
    deinit {
        stopMixing()
    }
}