import Testing
import Foundation
import AVFoundation
import Synchronization
@testable import MeetingRecorder

@Suite("AudioFileWriter", .serialized)
struct AudioFileWriterTests {

    private func sine(format: AVAudioFormat, seconds: Double, frequency: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channels = Int(format.channelCount)
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let value = Float(sin(2 * .pi * frequency * Double(i) / format.sampleRate)) * 0.3
            if format.isInterleaved {
                for c in 0..<channels { data[i * channels + c] = value }
            } else {
                for c in 0..<channels { buffer.floatChannelData![c][i] = value }
            }
        }
        return buffer
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("meety-writer-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }

    @Test("Mixes a 44.1 kHz stereo tap and a 16 kHz mono mic into one mono AAC track")
    func mixesToMonoAAC() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let counters = CaptureCounters()
        let writer = try AudioFileWriter(outputURL: url, counters: counters)
        try writer.start()

        let tapFormat = CaptureFormat.halStreamFormat(sampleRate: 44_100, channels: 2)!
        let micFormat = CaptureFormat.halStreamFormat(sampleRate: 16_000, channels: 1)!
        writer.configure(systemFormat: tapFormat, microphoneFormat: micFormat)

        // 3 s in 100 ms slices, like an IOProc would deliver.
        for _ in 0..<30 {
            writer.enqueue(
                system: sine(format: tapFormat, seconds: 0.1, frequency: 440),
                microphone: sine(format: micFormat, seconds: 0.1, frequency: 220)
            )
        }
        let finished = try await writer.finish()
        #expect(finished == url)

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.count == 1)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 3.0) < 0.15)
        let descriptions = try await tracks[0].load(.formatDescriptions)
        let asbd = try #require(descriptions.first?.audioStreamBasicDescription)
        #expect(asbd.mFormatID == kAudioFormatMPEG4AAC)
        #expect(asbd.mSampleRate == 48_000)
        #expect(asbd.mChannelsPerFrame == 1)
        #expect(counters.droppedFrames.load(ordering: .relaxed) == 0)
    }

    @Test("Inserted silence extends the file and finish is idempotent")
    func silenceAndIdempotentFinish() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AudioFileWriter(outputURL: url, counters: CaptureCounters())
        try writer.start()
        let tapFormat = CaptureFormat.halStreamFormat(sampleRate: 48_000, channels: 2)!
        writer.configure(systemFormat: tapFormat, microphoneFormat: nil)
        writer.enqueue(system: sine(format: tapFormat, seconds: 1.0, frequency: 440), microphone: nil)
        writer.insertSilence(seconds: 2.0)
        _ = try await writer.finish()
        _ = try await writer.finish()

        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        #expect(abs(duration - 3.0) < 0.15)
    }

    @Test("Partial URL sits next to the final file with a .partial infix")
    func partialURL() {
        let final = URL(fileURLWithPath: "/Users/me/Documents/meeting_2026-09-21_10-00-00.m4a")
        let partial = CaptureEngine.partialURL(for: final)
        #expect(partial.lastPathComponent == "meeting_2026-09-21_10-00-00.partial.m4a")
        #expect(partial.deletingLastPathComponent() == final.deletingLastPathComponent())
    }
}
