import CoreAudio
import Foundation

/// Maps the buffers of the aggregate device's input `AudioBufferList` to their
/// source. Pure and testable; inferred once per tap start from the HAL stream
/// configuration and logged.
struct CaptureStreamLayout: Sendable, Equatable {
    enum Source: Sendable, Equatable { case systemTap, microphone }

    struct Stream: Sendable, Equatable {
        let bufferIndex: Int
        let channels: Int
        let source: Source
    }

    let streams: [Stream]
    let sampleRate: Double

    var tapStreams: [Stream] { streams.filter { $0.source == .systemTap } }
    var microphoneStreams: [Stream] { streams.filter { $0.source == .microphone } }
    var hasMicrophone: Bool { !microphoneStreams.isEmpty }

    /// Float32 frames in an IO buffer, or nil when its channel count no longer matches
    /// the stream's format: unplugging a sub-device reshapes the buffer list before the
    /// tap is rebuilt, and copying it would overrun the PCM buffer (heap corruption).
    static func frameCount(of buffer: AudioBuffer, channels: Int) -> Int? {
        guard Int(buffer.mNumberChannels) == channels, channels > 0 else { return nil }
        let frames = Int(buffer.mDataByteSize) / (channels * MemoryLayout<Float>.size)
        return frames > 0 ? frames : nil
    }

    /// Infers the layout from per-buffer channel counts.
    ///
    /// The HAL lists sub-device streams first and tap streams last, so the
    /// expected shape is `micStreams + [tap]`. The reverse order and a tap-only
    /// aggregate are also accepted. Returns nil when the shape matches nothing.
    static func infer(
        bufferChannelCounts: [Int],
        microphoneStreamChannelCounts: [Int],
        tapChannelCount: Int,
        sampleRate: Double
    ) -> CaptureStreamLayout? {
        func build(micFirst: Bool) -> CaptureStreamLayout {
            var streams: [Stream] = []
            let micRange =
                micFirst
                ? 0..<microphoneStreamChannelCounts.count
                : 1..<(1 + microphoneStreamChannelCounts.count)
            for (index, channels) in bufferChannelCounts.enumerated() {
                let source: Source = micRange.contains(index) ? .microphone : .systemTap
                streams.append(Stream(bufferIndex: index, channels: channels, source: source))
            }
            return CaptureStreamLayout(streams: streams, sampleRate: sampleRate)
        }

        if bufferChannelCounts == microphoneStreamChannelCounts + [tapChannelCount] {
            return build(micFirst: true)
        }
        if bufferChannelCounts == [tapChannelCount] + microphoneStreamChannelCounts {
            return build(micFirst: false)
        }
        if microphoneStreamChannelCounts.isEmpty, bufferChannelCounts == [tapChannelCount] {
            return build(micFirst: true)
        }
        return nil
    }
}
