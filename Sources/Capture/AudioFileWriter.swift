import Foundation
import Synchronization
import AVFoundation
import CoreMedia
import os

/// Transfers an `AVAudioPCMBuffer` across queues. The buffer is a fresh copy
/// owned by the sender and never touched again after `enqueue` — hence
/// `@unchecked Sendable`.
struct PCMTransfer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

/// Encodes the mixed mono stream to AAC in an `.m4a` via `AVAssetWriter`.
///
/// All mutable state is confined to `queue`; `enqueue` is the only entry point
/// called from the IO path and it just hops onto that queue. Hence
/// `@unchecked Sendable` — the invariant is "every member runs on `queue`".
final class AudioFileWriter: @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.meetingrecorder.meety.capture.writer", qos: .userInitiated)
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let canonical = CaptureFormat.canonical()
    private let counters: CaptureCounters
    let outputURL: URL

    // Per-source conversion state (rebuilt on every tap start).
    private var systemConverter: AVAudioConverter?
    private var microphoneConverter: AVAudioConverter?
    private var systemFIFO: [Float] = []
    private var microphoneFIFO: [Float] = []
    private var hasMicrophone = false

    private var activity = VoiceActivityRecorder()
    /// The activity sidecar only makes sense if a microphone was captured at some point.
    private var sawMicrophone = false

    private var framesWritten: Int64 = 0
    private var started = false
    private var finished = false
    private var appendFailure: String?

    // MARK: - Init

    init(outputURL: URL, counters: CaptureCounters) throws(CaptureFailure) {
        self.outputURL = outputURL
        self.counters = counters
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        } catch {
            throw .writer(error.localizedDescription)
        }
        input = AVAssetWriterInput(mediaType: .audio, outputSettings: CaptureFormat.writerOutputSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        // Periodic fragments keep the file playable if the process dies mid-recording.
        writer.movieFragmentInterval = CMTime(seconds: Constants.Recording.fragmentInterval, preferredTimescale: 600)
    }

    // MARK: - Session

    func start() throws(CaptureFailure) {
        var failure: CaptureFailure?
        queue.sync {
            guard !started else { return }
            guard writer.startWriting() else {
                failure = .writer(writer.error?.localizedDescription ?? "startWriting failed")
                return
            }
            writer.startSession(atSourceTime: .zero)
            started = true
        }
        if let failure { throw failure }
    }

    /// Declares the incoming stream formats for the current tap session.
    func configure(systemFormat: AVAudioFormat, microphoneFormat: AVAudioFormat?) {
        queue.async { [self] in
            systemConverter = AVAudioConverter(
                from: systemFormat,
                to: CaptureFormat.intermediate(channels: systemFormat.channelCount)
            )
            if let microphoneFormat {
                microphoneConverter = AVAudioConverter(
                    from: microphoneFormat,
                    to: CaptureFormat.intermediate(channels: microphoneFormat.channelCount)
                )
                hasMicrophone = true
                sawMicrophone = true
            } else {
                microphoneConverter = nil
                hasMicrophone = false
            }
            systemFIFO.removeAll(keepingCapacity: true)
            microphoneFIFO.removeAll(keepingCapacity: true)
        }
    }

    /// Called from the IO queue. Buffers are already copies owned by the caller.
    func enqueue(system: AVAudioPCMBuffer?, microphone: AVAudioPCMBuffer?) {
        let frames = Int(system?.frameLength ?? microphone?.frameLength ?? 0)
        let systemTransfer = system.map(PCMTransfer.init)
        let microphoneTransfer = microphone.map(PCMTransfer.init)
        counters.pendingFrames.add(frames, ordering: .relaxed)
        queue.async { [self] in
            defer { counters.pendingFrames.subtract(frames, ordering: .relaxed) }
            guard started, !finished else { return }
            if let systemTransfer, let systemConverter {
                systemFIFO.append(contentsOf: convertToMono(systemTransfer.buffer, using: systemConverter))
            }
            if let microphoneTransfer, let microphoneConverter {
                microphoneFIFO.append(contentsOf: convertToMono(microphoneTransfer.buffer, using: microphoneConverter))
            }
            drainMix(flush: false)
        }
    }

    /// Appends `seconds` of silence (used to keep wall-clock alignment across tap restarts).
    func insertSilence(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let frames = Int(seconds * CaptureFormat.sampleRate)
        queue.async { [self] in
            guard started, !finished else { return }
            drainMix(flush: true)
            activity.addSilence(frames: frames)
            append(samples: [Float](repeating: 0, count: frames))
        }
    }

    /// Microphone vs system levels over the file, or nil without a microphone.
    /// Read after `finish()`.
    var voiceActivity: VoiceActivity? {
        queue.sync { sawMicrophone ? activity.result() : nil }
    }

    /// Drains pending audio, closes the input and finishes the file.
    func finish() async throws(CaptureFailure) -> URL {
        let alreadyFinished: Bool = await withCheckedContinuation { continuation in
            queue.async { [self] in
                if finished || !started {
                    continuation.resume(returning: true)
                    return
                }
                finished = true
                drainMix(flush: true)
                input.markAsFinished()
                continuation.resume(returning: false)
            }
        }
        if alreadyFinished {
            if writer.status == .completed { return outputURL }
            throw .writer(appendFailure ?? "writer never started")
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            let detail = writer.error?.localizedDescription ?? appendFailure ?? "status \(writer.status.rawValue)"
            if let nsError = writer.error as NSError?, nsError.domain == NSCocoaErrorDomain,
                nsError.code == NSFileWriteOutOfSpaceError
            {
                throw .diskFull
            }
            throw .writer(detail)
        }
        return outputURL
    }

    func cancel() {
        queue.async { [self] in
            finished = true
            if writer.status == .writing { writer.cancelWriting() }
        }
    }

    var writtenDuration: TimeInterval {
        queue.sync { TimeInterval(framesWritten) / CaptureFormat.sampleRate }
    }

    // MARK: - Mixing (queue-confined)

    private func drainMix(flush: Bool) {
        let count: Int
        if hasMicrophone {
            count = flush ? max(systemFIFO.count, microphoneFIFO.count) : min(systemFIFO.count, microphoneFIFO.count)
        } else {
            count = systemFIFO.count
        }
        guard count > 0 else { return }

        activity.add(
            system: systemFIFO.prefix(count),
            microphone: hasMicrophone ? microphoneFIFO.prefix(count) : [],
            count: count
        )

        var mixed = [Float](repeating: 0, count: count)
        for i in 0..<min(count, systemFIFO.count) { mixed[i] = systemFIFO[i] }
        if hasMicrophone {
            for i in 0..<min(count, microphoneFIFO.count) { mixed[i] += microphoneFIFO[i] }
        }
        for i in 0..<count { mixed[i] = softClip(mixed[i]) }

        systemFIFO.removeFirst(min(count, systemFIFO.count))
        microphoneFIFO.removeFirst(min(count, microphoneFIFO.count))
        append(samples: mixed)
    }

    private func softClip(_ x: Float) -> Float {
        // Transparent below ±0.8, smooth compression above, never exceeds ±1.
        let a = abs(x)
        if a <= 0.8 { return x }
        let compressed = 0.8 + (1 - 0.8) * tanh((a - 0.8) / (1 - 0.8))
        return x < 0 ? -compressed : compressed
    }

    /// Rate-converts to 48 kHz keeping channels, then averages channels to mono.
    private func convertToMono(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> [Float] {
        let ratio = CaptureFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return [] }

        let source = PCMTransfer(buffer: buffer)
        let consumed = Atomic<Bool>(false)
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if consumed.exchange(true, ordering: .relaxed) {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            return source.buffer
        }
        if status == .error {
            Log.capture.error("Audio conversion failed: \(error?.localizedDescription ?? "?", privacy: .public)")
            return []
        }
        let frames = Int(out.frameLength)
        guard frames > 0, let channels = out.floatChannelData else { return [] }
        let channelCount = Int(out.format.channelCount)
        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channels[0], count: frames))
        }
        var mono = [Float](repeating: 0, count: frames)
        let scale = 1 / Float(channelCount)
        for c in 0..<channelCount {
            let channel = channels[c]
            for i in 0..<frames { mono[i] += channel[i] * scale }
        }
        return mono
    }

    private func append(samples: [Float]) {
        guard !samples.isEmpty, input.isReadyForMoreMediaData else {
            if !samples.isEmpty { counters.droppedFrames.add(UInt64(samples.count), ordering: .relaxed) }
            return
        }
        guard let sampleBuffer = makeSampleBuffer(samples) else {
            counters.droppedFrames.add(UInt64(samples.count), ordering: .relaxed)
            return
        }
        if input.append(sampleBuffer) {
            framesWritten += Int64(samples.count)
        } else if appendFailure == nil {
            appendFailure = writer.error?.localizedDescription ?? "append failed"
            Log.capture.error("AVAssetWriterInput.append failed: \(self.appendFailure ?? "?", privacy: .public)")
        }
    }

    private func makeSampleBuffer(_ samples: [Float]) -> CMSampleBuffer? {
        guard let pcm = AVAudioPCMBuffer(pcmFormat: canonical, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = pcm.floatChannelData?[0]
        else { return nil }
        pcm.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }

        let timescale = CMTimeScale(CaptureFormat.sampleRate)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: timescale),
            presentationTimeStamp: CMTime(value: framesWritten, timescale: timescale),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        var status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: canonical.formatDescription,
            sampleCount: CMItemCount(samples.count),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else { return nil }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: pcm.audioBufferList
        )
        return status == noErr ? sampleBuffer : nil
    }
}
