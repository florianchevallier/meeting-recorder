import Foundation
import Observation
import os

/// Runs live transcription alongside a recording: one on-device transcriber per
/// source ("me" = microphone, "them" = system audio), the transcript shown in the
/// live panel, and final segments appended to `<recording>.live.md` as they come
/// (so a crash keeps everything already finalized).
@MainActor
@Observable
final class LiveTranscriptionCoordinator {

    enum Status: Equatable {
        case idle
        /// Resolving the language / downloading the on-device model.
        case preparing
        case running
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    private(set) var transcript = LiveTranscript()
    /// Bumped at every session start (the panel opens itself on change).
    private(set) var sessionCount = 0

    private let settings: SettingsStore
    private var session: Session?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    // MARK: - Session

    /// One recording's worth of state. Audio flows in through the sink before the
    /// transcribers exist (model download), buffered by the bounded streams.
    private final class Session {
        let fileURL: URL
        let audio: [LiveSpeaker: AsyncStream<[Float]>]
        let continuations: [LiveSpeaker: AsyncStream<[Float]>.Continuation]
        var transcribers: [LiveSpeaker: LiveSpeechTranscriber] = [:]
        var feeders: [Task<Void, Never>] = []
        var consumers: [Task<Void, Never>] = []
        var setupTask: Task<Void, Never>?
        var file: FileHandle?

        init(fileURL: URL) {
            self.fileURL = fileURL
            var audio: [LiveSpeaker: AsyncStream<[Float]>] = [:]
            var continuations: [LiveSpeaker: AsyncStream<[Float]>.Continuation] = [:]
            for speaker in LiveSpeaker.allCases {
                let (stream, continuation) = AsyncStream<[Float]>.makeStream(
                    bufferingPolicy: .bufferingNewest(Constants.Live.maxBufferedChunks))
                audio[speaker] = stream
                continuations[speaker] = continuation
            }
            self.audio = audio
            self.continuations = continuations
        }
    }

    /// Starts a session for the recording at `recordingURL` and returns the sink to
    /// hand to the capture engine, or `nil` when live transcription is off.
    func begin(recordingURL: URL) -> LiveAudioSink? {
        guard settings.liveTranscriptionEnabled, session == nil else { return nil }
        let session = Session(fileURL: RecordingFiles(audio: recordingURL).liveTranscript)
        self.session = session
        transcript = LiveTranscript()
        status = .preparing
        sessionCount += 1

        let language = settings.language
        session.setupTask = Task { [weak self] in
            await self?.startTranscribers(for: session, languageCode: language)
        }

        let me = session.continuations[.me]!
        let them = session.continuations[.them]!
        return { system, microphone in
            if !system.isEmpty { them.yield(system) }
            if !microphone.isEmpty { me.yield(microphone) }
        }
    }

    private func startTranscribers(for session: Session, languageCode: String) async {
        do {
            let locale = try await LiveSpeechTranscriber.prepare(languageCode: languageCode)
            for speaker in LiveSpeaker.allCases {
                let transcriber = try await LiveSpeechTranscriber(speaker: speaker, locale: locale)
                session.transcribers[speaker] = transcriber
                let audio = session.audio[speaker]!
                session.feeders.append(
                    Task {
                        for await chunk in audio { await transcriber.feed(chunk) }
                    })
                session.consumers.append(
                    Task { [weak self] in
                        for await update in transcriber.updates { self?.handle(update, in: session) }
                    })
            }
            if Task.isCancelled {
                // The recording ended while we were preparing: release the analyzers.
                for transcriber in session.transcribers.values { await transcriber.cancel() }
                return
            }
            guard self.session === session else { return }
            status = .running
            Log.transcription.info("Live transcription running (\(locale.identifier, privacy: .public))")
        } catch {
            Log.transcription.error("Live transcription unavailable: \(String(describing: error), privacy: .public)")
            if self.session === session { status = .unavailable(Self.message(for: error)) }
        }
    }

    private func handle(_ update: LiveTranscriptUpdate, in session: Session) {
        guard self.session === session else { return }
        transcript.apply(update)
        guard update.isFinal,
            let segment = transcript.segments.last(where: { $0.isFinal && $0.speaker == update.speaker })
        else { return }
        append(LiveTranscript.markdownLine(for: segment) + "\n\n", to: session)
    }

    private func append(_ text: String, to session: Session) {
        do {
            if session.file == nil {
                FileManager.default.createFile(atPath: session.fileURL.path, contents: nil)
                session.file = try FileHandle(forWritingTo: session.fileURL)
            }
            try session.file?.seekToEnd()
            try session.file?.write(contentsOf: Data(text.utf8))
        } catch {
            Log.transcription.error("Live transcript not written: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Flushes the last results once the capture engine stopped feeding audio.
    /// Bounded by `Constants.Live.finalizationTimeout`: past it the analyzers are
    /// cancelled, which unblocks everything below.
    func end() async {
        guard let session else { return }
        for continuation in session.continuations.values { continuation.finish() }
        if status == .preparing {
            // Still resolving / downloading the model: don't hold the stop hostage to it.
            session.setupTask?.cancel()
        } else {
            await session.setupTask?.value
        }

        let transcribers = Array(session.transcribers.values)
        let feeders = session.feeders
        let consumers = session.consumers
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for feeder in feeders { await feeder.value }
                await withTaskGroup(of: Void.self) { finishing in
                    for transcriber in transcribers { finishing.addTask { await transcriber.finish() } }
                }
                for consumer in consumers { await consumer.value }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(Constants.Live.finalizationTimeout))
                guard !Task.isCancelled else { return }
                Log.transcription.warning("Live transcription finalization timed out")
                for transcriber in transcribers { await transcriber.cancel() }
            }
            await group.next()
            group.cancelAll()
        }

        try? session.file?.close()
        if self.session === session {
            self.session = nil
            status = .idle
        }
        Log.transcription.info("Live transcription ended (\(self.transcript.segments.count) segments)")
    }

    // MARK: - Helpers

    private static func message(for error: any Error) -> String {
        switch error as? LiveTranscriptionFailure {
        case .unsupportedLanguage(let code): return L10n.liveErrorUnsupportedLanguage(code)
        case .assetsUnavailable(let detail), .analyzer(let detail): return L10n.liveErrorUnavailable(detail)
        case nil: return L10n.liveErrorUnavailable(error.localizedDescription)
        }
    }
}
