import Foundation
import AVFoundation
import CoreAudio
import Synchronization
import os

/// Deterministic check of the "System Audio Recording Only" permission, which
/// has no public status API: play a short tone ourselves and see whether a tap
/// on our own process receives it. The first run triggers the TCC prompt.
struct SystemAudioPermissionProbe: Sendable {
    enum Outcome: Sendable, Equatable {
        case audioReceived
        case silence
        case failed(CaptureFailure)
    }

    var duration: TimeInterval = 1.0
    /// Linear amplitude above which the tap is considered live (-60 dBFS).
    var threshold: Float = 0.001

    func run() async -> Outcome {
        let engine = AVAudioEngine()
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate, channels: 1)!
        let phase = Mutex<Double>(0)
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let increment = 2 * Double.pi * 440 / format.sampleRate
            phase.withLock { current in
                for frame in 0..<Int(frameCount) {
                    let value = Float(sin(current)) * 0.03  // ≈ -30 dBFS
                    current += increment
                    if current > 2 * Double.pi { current -= 2 * Double.pi }
                    for buffer in buffers {
                        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                    }
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            return .failed(.writer("AVAudioEngine: \(error.localizedDescription)"))
        }
        defer { engine.stop() }

        let ownProcess = CoreAudioProperties.ownProcessObject()
        var configuration = ProcessTapController.Configuration()
        configuration.includeMicrophone = false
        configuration.excludeOwnProcess = false
        configuration.processObjects = ownProcess.isValid ? [ownProcess] : nil

        let tap = ProcessTapController(configuration: configuration)
        let peak = Mutex<Float>(0)
        do {
            try tap.start { inputData, _, _, formats in
                let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
                for stream in formats where stream.source == .systemTap && stream.bufferIndex < list.count {
                    let buffer = list[stream.bufferIndex]
                    guard let data = buffer.mData else { continue }
                    let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count)
                    var localPeak: Float = 0
                    for sample in samples { localPeak = max(localPeak, abs(sample)) }
                    peak.withLock { $0 = max($0, localPeak) }
                }
            }
        } catch {
            Log.permissions.error("System audio probe failed: \(error.localizedDescription, privacy: .public)")
            return .failed(error)
        }
        defer { tap.stop() }

        try? await Task.sleep(for: .seconds(duration))
        let measured = peak.withLock { $0 }
        Log.permissions.info("System audio probe peak: \(measured, format: .fixed(precision: 4))")
        return measured >= threshold ? .audioReceived : .silence
    }
}
