import Foundation
import ScreenCaptureKit
import CoreMedia

/// Bridges ScreenCaptureKit delegate callbacks (delivered on private SCK queues)
/// into the `CaptureEngine` actor, and counts incoming samples per stream type.
///
/// The sample counters are the health monitor's liveness signal: the old direct
/// mode never attached an `SCStreamOutput`, so health monitoring never saw a
/// single sample. Buffers are counted and immediately discarded — negligible CPU.
///
/// `@unchecked Sendable`: sample stats are protected by `statsLock`; the engine
/// is only touched through `Task`-hopped actor calls.
final class StreamDelegateBridge: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, SCStreamOutput, @unchecked Sendable {

    private weak var engine: CaptureEngine?

    let screenQueue = DispatchQueue(label: "Meety.Capture.ScreenQueue", qos: .userInitiated)
    let audioQueue = DispatchQueue(label: "Meety.Capture.AudioQueue", qos: .userInitiated)
    let microphoneQueue = DispatchQueue(label: "Meety.Capture.MicrophoneQueue", qos: .userInitiated)

    private let statsLock = NSLock()
    private var _sampleCount = 0
    private var _lastSampleTime: Date?

    init(engine: CaptureEngine) {
        self.engine = engine
        super.init()
    }

    // MARK: - Sample Statistics (lock-protected, read by the engine's health loop)

    func markStarted() {
        statsLock.lock()
        _sampleCount = 0
        _lastSampleTime = Date()
        statsLock.unlock()
    }

    func sampleStats() -> (count: Int, lastTime: Date?) {
        statsLock.lock()
        defer { statsLock.unlock() }
        return (_sampleCount, _lastSampleTime)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let engine = self.engine
        Task { await engine?.streamDidStop(with: error) }
    }

    // MARK: - SCRecordingOutputDelegate

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        let engine = self.engine
        Task { await engine?.recordingOutputDidFail(with: error) }
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        let engine = self.engine
        Task { await engine?.recordingDidFinish() }
    }

    // MARK: - SCStreamOutput (sample counting only, buffers discarded)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        statsLock.lock()
        _sampleCount += 1
        _lastSampleTime = Date()
        let count = _sampleCount
        statsLock.unlock()

        // Occasional liveness log (audio/mic are the interesting signals)
        if count % 500 == 0, type == .audio || type == .microphone {
            Logger.shared.debug("Samples flowing (\(count))", component: "CAPTURE")
        }
    }
}
