import os
import Foundation

/// Transcribes recordings one at a time: upload → poll → download the JSON →
/// render the `.txt` next to the recording → delete the job on the server.
/// A job in flight is persisted (`.transcription-job.json`) so a relaunch
/// resumes polling. UI state flows through the pure `TranscriptionState` reducer.
@MainActor
@Observable
final class TranscriptionCoordinator {

    // MARK: - Observable State

    private(set) var state = TranscriptionState()
    /// Recording being transcribed.
    private(set) var current: URL?
    /// Recordings waiting behind `current`.
    private(set) var queue: [URL] = []
    /// Last recording that failed, for "Retry".
    private(set) var lastFailed: URL?

    // MARK: - Dependencies

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let apiKey: @MainActor () -> String?
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var workerID = UUID()

    // MARK: - Init

    init(
        settings: SettingsStore,
        apiKey: @escaping @MainActor () -> String? = {
            KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount)
        }
    ) {
        self.settings = settings
        self.apiKey = apiKey
    }

    // MARK: - Pre-Indication (called by RecordingCoordinator during stop)

    /// Show the transcription panel early, while the recording is finalized.
    func preIndicate() {
        apply(.prepare)
    }

    func notifyConversionInProgress() {
        apply(.conversionInProgress)
    }

    func notifyNoFileGenerated() {
        apply(.failed(L10n.transcriptionErrorNoFile))
    }

    // MARK: - Queue

    /// True while `audioURL` is being transcribed or waiting its turn.
    func isPending(_ audioURL: URL) -> Bool {
        current == audioURL || queue.contains(audioURL)
    }

    /// Transcribe `audioURL` after the recordings already queued. The calendar
    /// event is read from its `.meeting.json` sidecar.
    func enqueue(_ audioURL: URL) {
        guard !isPending(audioURL) else { return }
        Log.transcription.info("Queued for transcription: \(audioURL.lastPathComponent, privacy: .public)")
        queue.append(audioURL)
        startWorkerIfNeeded()
    }

    /// Resume the jobs a previous run left on the server.
    func resumePending(in recordings: [URL]) {
        for recording in recordings
        where FileManager.default.fileExists(atPath: RecordingFiles(audio: recording).pendingJob.path) {
            Log.transcription.info("Resuming transcription of \(recording.lastPathComponent, privacy: .public)")
            enqueue(recording)
        }
    }

    func retry() {
        guard let lastFailed else { return }
        self.lastFailed = nil
        enqueue(lastFailed)
    }

    /// Cancel the current transcription and everything queued. The server job
    /// is deleted too (it stops the processing there).
    func cancel() {
        Log.transcription.info("Cancelling transcription")
        worker?.cancel()
        worker = nil
        workerID = UUID()
        if let current {
            let pendingURL = RecordingFiles(audio: current).pendingJob
            if let job = try? PendingTranscriptionJob.read(from: pendingURL) {
                let client = makeClient()
                Task { try? await client.deleteJob(jobId: job.jobId) }
            }
            try? FileManager.default.removeItem(at: pendingURL)
        }
        current = nil
        queue.removeAll()
        apply(.reset)
    }

    // MARK: - Worker

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        let id = UUID()
        workerID = id
        worker = Task { [weak self] in
            while let self, !Task.isCancelled, !self.queue.isEmpty {
                let next = self.queue.removeFirst()
                self.current = next
                await self.transcribe(next)
                if self.workerID == id { self.current = nil }
            }
            if let self, self.workerID == id { self.worker = nil }
        }
    }

    private func transcribe(_ audioURL: URL) async {
        let files = RecordingFiles(audio: audioURL)
        let client = makeClient()
        apply(.prepare)

        do {
            let jobId = try await submitIfNeeded(audioURL, files: files, client: client)
            try await waitForCompletion(client: client, jobId: jobId)

            Log.transcription.info("Job completed, downloading result…")
            let data = try await client.downloadResult(jobId: jobId)
            _ = try Transcript.decode(data)  // never overwrite a good transcript with garbage
            try data.write(to: files.transcriptJSON, options: .atomic)
            try TranscriptFiles.writeText(for: audioURL)
            try? FileManager.default.removeItem(at: files.pendingJob)
            Log.transcription.info(
                "Transcription saved to: \(files.transcriptText.lastPathComponent, privacy: .public)")

            do {
                try await client.deleteJob(jobId: jobId)
            } catch {
                Log.transcription.warning("Job not deleted on server: \(error.localizedDescription, privacy: .public)")
            }

            apply(.saved)
            // Show the success message briefly, unless another recording is waiting
            if queue.isEmpty {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled && queue.isEmpty { apply(.reset) }
            }
        } catch  where Task.isCancelled || error is CancellationError {
            return
        } catch {
            Log.transcription.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            // A network failure keeps the job: the next launch resumes it.
            // Anything else (job failed or unknown on the server) starts over on retry.
            if !(error is URLError) {
                try? FileManager.default.removeItem(at: files.pendingJob)
            }
            lastFailed = audioURL
            apply(.failed(error.localizedDescription))
        }
    }

    /// Job id of the pending job, or of a freshly uploaded one.
    private func submitIfNeeded(_ audioURL: URL, files: RecordingFiles, client: WhisperAPIClient) async throws
        -> String
    {
        if let pending = try? PendingTranscriptionJob.read(from: files.pendingJob) {
            apply(.jobCreated(pending.jobId))
            return pending.jobId
        }

        apply(.uploadStarted)
        let event = (try? MeetingMetadata.read(forRecording: audioURL))?.event
        let hints = TranscriptionHints.make(
            event: event, glossary: settings.transcriptionGlossary, maxSpeakers: settings.nbSpeaker)
        Log.transcription.info(
            "Speakers \(hints.minSpeakers ?? 0)…\(hints.maxSpeakers ?? 0), prompt \(hints.initialPrompt?.count ?? 0) chars"
        )

        let response = try await client.startTranscription(audioFileURL: audioURL, parameters: parameters(hints))
        try PendingTranscriptionJob(jobId: response.jobId, submittedAt: Date()).write(to: files.pendingJob)
        apply(.jobCreated(response.jobId))
        return response.jobId
    }

    private func waitForCompletion(client: WhisperAPIClient, jobId: String) async throws {
        // Let the server register the job before the first poll
        try await Task.sleep(for: .seconds(Constants.Transcription.initialPollingDelay))

        var failures = 0
        for _ in 0..<Constants.Transcription.maxPollingAttempts {
            do {
                let job = try await client.getJobStatus(jobId: jobId).job
                apply(.statusUpdated(job.status))
                if let lastLog = job.lastLog {
                    apply(.progressMessage(lastLog))
                }
                switch job.status {
                case .completed:
                    return
                case .failed:
                    throw TranscriptionFailure.jobFailed
                case .pending, .running:
                    break
                }
            } catch let error as URLError where error.code != .cancelled {
                // Transient network error (tunnel restart, Wi-Fi): keep polling.
                failures += 1
                Log.transcription.warning("Polling error \(failures): \(error.localizedDescription, privacy: .public)")
            }
            try await Task.sleep(for: .seconds(Constants.Transcription.pollingInterval))
        }
        throw TranscriptionFailure.tooLong
    }

    // MARK: - Parameters

    private func parameters(_ hints: TranscriptionHints) -> TranscriptionRequest {
        TranscriptionRequest(
            model: settings.whisperModel,
            language: settings.language,
            computeType: settings.computeType,
            minSpeakers: hints.minSpeakers,
            maxSpeakers: hints.maxSpeakers,
            initialPrompt: hints.initialPrompt
        )
    }

    private func makeClient() -> WhisperAPIClient {
        WhisperAPIClient(baseURL: settings.apiBaseURL, apiKey: apiKey())
    }

    // MARK: - Reducer Bridge

    private func apply(_ event: TranscriptionEvent) {
        TranscriptionStateReducer.reduce(&state, event)
    }
}

/// Server-side outcomes that end a transcription.
enum TranscriptionFailure: LocalizedError {
    case jobFailed
    case tooLong

    var errorDescription: String? {
        switch self {
        case .jobFailed: return L10n.transcriptionErrorJobFailed
        case .tooLong: return L10n.transcriptionErrorTooLong
        }
    }
}
