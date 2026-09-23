import AVFoundation
import CoreMedia
import Foundation
import Speech
import Synchronization
import os

/// Why live transcription could not start.
enum LiveTranscriptionFailure: Error, Equatable, Sendable {
    case unsupportedLanguage(String)
    case assetsUnavailable(String)
    case analyzer(String)
}

/// One on-device `SpeechAnalyzer` + `SpeechTranscriber` session for one source.
///
/// Fed 48 kHz mono samples (see `LiveAudioSink`), converted here to the analyzer's
/// format. Results are timed from the first sample fed, i.e. from the start of the
/// recording. `.fastResults` is what makes words show up ~0.5 s after they are
/// spoken (measured: without it, volatile text lags 5–6 s).
actor LiveSpeechTranscriber {

    nonisolated let updates: AsyncStream<LiveTranscriptUpdate>
    private let updatesContinuation: AsyncStream<LiveTranscriptUpdate>.Continuation

    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let converter: AVAudioConverter
    private let sourceFormat: AVAudioFormat
    private var resultsTask: Task<Void, Never>?

    /// Resolves the locale for `languageCode` and installs its model if needed
    /// (downloaded once by the system, shared by every app).
    static func prepare(languageCode: String) async throws(LiveTranscriptionFailure) -> Locale {
        let requested = requestedLocale(for: languageCode)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested)
        else { throw .unsupportedLanguage(languageCode) }
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [makeModule(locale)]) {
                Log.transcription.info("Downloading speech model for \(locale.identifier, privacy: .public)")
                try await request.downloadAndInstall()
            }
        } catch {
            throw .assetsUnavailable(error.localizedDescription)
        }
        return locale
    }

    /// A bare language code is ambiguous (`fr` resolved to fr_CA): use the Mac's own
    /// region when it speaks that language, otherwise the language's home region.
    static func requestedLocale(for languageCode: String, current: Locale = .current) -> Locale {
        if current.language.languageCode?.identifier == languageCode, let region = current.region?.identifier {
            return Locale(identifier: "\(languageCode)_\(region)")
        }
        let homeRegion = ["en": "US", "fr": "FR", "de": "DE", "es": "ES", "it": "IT", "pt": "PT"]
        return Locale(identifier: "\(languageCode)_\(homeRegion[languageCode] ?? languageCode.uppercased())")
    }

    private static func makeModule(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
    }

    init(speaker: LiveSpeaker, locale: Locale) async throws(LiveTranscriptionFailure) {
        (updates, updatesContinuation) = AsyncStream.makeStream()
        let module = Self.makeModule(locale)
        let source = CaptureFormat.intermediate(channels: 1)
        guard
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [module], considering: source),
            let converter = AVAudioConverter(from: source, to: format)
        else { throw .analyzer("no compatible audio format") }
        self.sourceFormat = source
        self.converter = converter

        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        self.input = input
        analyzer = SpeechAnalyzer(modules: [module])
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            throw .analyzer(error.localizedDescription)
        }

        let continuation = updatesContinuation
        resultsTask = Task {
            do {
                for try await result in module.results {
                    continuation.yield(
                        LiveTranscriptUpdate(
                            speaker: speaker,
                            text: String(result.text.characters),
                            start: result.range.start.seconds,
                            isFinal: result.isFinal
                        ))
                }
            } catch {
                Log.transcription.error(
                    "Live transcriber (\(speaker.rawValue, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            continuation.finish()
        }
    }

    /// Converts and forwards one chunk of 48 kHz mono samples.
    func feed(_ samples: [Float]) {
        guard !samples.isEmpty,
            let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }

        let ratio = converter.outputFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(samples.count) * ratio) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            return
        }
        let source = PCMTransfer(buffer: buffer)
        let consumed = Atomic<Bool>(false)
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, outStatus in
            if consumed.exchange(true, ordering: .relaxed) {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            return source.buffer
        }
        guard status != .error, converted.frameLength > 0 else { return }
        input.yield(AnalyzerInput(buffer: converted))
    }

    /// Ends the input and waits for the last final results.
    func finish() async {
        input.finish()
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            Log.transcription.error("Live finalize failed: \(error.localizedDescription, privacy: .public)")
        }
        await resultsTask?.value
    }

    /// Gives up on pending results (finalization ceiling hit).
    func cancel() async {
        await analyzer.cancelAndFinishNow()
        resultsTask?.cancel()
    }
}
