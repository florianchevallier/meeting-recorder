import Foundation
import AVFoundation

protocol MicrophoneCaptureDelegate: AnyObject {
    func microphoneCapture(_ capture: MicrophoneCapture, didReceiveAudioBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime) async
}

class MicrophoneCapture: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bufferSize: AVAudioFrameCount = 1024
    
    weak var delegate: MicrophoneCaptureDelegate?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
    }
    
    func startCapture() throws {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            throw AudioCaptureError.captureInitializationFailed
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
        
        try audioEngine.start()
    }
    
    func stopCapture() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
    
    func getInputFormat() -> AVAudioFormat? {
        return inputNode?.outputFormat(forBus: 0)
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        Task {
            await delegate?.microphoneCapture(self, didReceiveAudioBuffer: buffer, at: time)
        }
    }
    
    deinit {
        stopCapture()
    }
}