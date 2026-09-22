import Foundation
import AVFoundation

/// Canonical PCM format and encoder settings. Everything the tap or the
/// microphone delivers is converted to `canonical()` before mixing.
enum CaptureFormat {
    static let sampleRate: Double = 48_000
    static let channels: AVAudioChannelCount = 1
    static let aacBitRate = 96_000

    /// Float32, mono, non-interleaved, 48 kHz.
    static func canonical() -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
    }

    /// Same rate/layout as `canonical()` but keeping the source channel count,
    /// so the mixdown can average channels explicitly.
    static func intermediate(channels: AVAudioChannelCount) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
    }

    /// AVAssetWriterInput settings: AAC-LC mono 48 kHz.
    static var writerOutputSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channels),
            AVEncoderBitRateKey: aacBitRate,
        ]
    }

    /// Float32 interleaved format of one HAL stream (what an IOProc delivers per buffer).
    static func halStreamFormat(sampleRate: Double, channels: AVAudioChannelCount) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        )
    }
}
