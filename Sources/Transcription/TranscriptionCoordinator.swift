import Foundation

/// Orchestrates the transcription workflow: upload → poll → download → save
/// the `.txt` next to the recording. UI state flows through the pure
/// `TranscriptionState` reducer.
///
/// Replaces `TranscriptionManager` (ObservableObject/@Published).
@MainActor
@Observable
final class TranscriptionCoordinator {

    // MARK: - Observable State

    private(set) var state = TranscriptionState()

    // MARK: - Dependencies

    private let settings: SettingsStore
    private var pollingTask: Task<Void, Never>?

    // MARK: - Init

    init(settings: SettingsStore) {
        self.settings = settings
    }

    // MARK: - Pre-Indication (called by RecordingCoordinator during stop)

    /// Show the transcription panel early, while the recording is finalized.
    func preIndicate() {
        apply(.prepare)
    }

    func notifyConversionInProgress() {
        apply(.conversionInProgress)
    }

    func notifyUploadStarted() {
        apply(.uploadStarted)
    }

    func notifyNoFileGenerated() {
        apply(.failed(L10n.transcriptionErrorNoFile))
    }

    // MARK: - Transcription Flow

    /// Start transcription of a recorded audio file.
    /// Returns after the job is created and polling has started.
    func transcribe(audioFileURL: URL) async {
        Logger.shared.info("Starting transcription for: \(audioFileURL.lastPathComponent)", component: "TRANSCRIPTION")

        do {
            let client = WhisperAPIClient(baseURL: settings.apiBaseURL)
            let jobResponse = try await client.startTranscription(
                audioFileURL: audioFileURL,
                parameters: currentParameters
            )

            apply(.jobCreated(jobResponse.jobId))
            Logger.shared.info("Job created: \(jobResponse.jobId)", component: "TRANSCRIPTION")

            startPolling(client: client, jobId: jobResponse.jobId, audioFileURL: audioFileURL)
        } catch {
            Logger.shared.error("Failed to start transcription: \(error.localizedDescription)", component: "TRANSCRIPTION")
            apply(.failed(error.localizedDescription))
        }
    }

    /// Cancel the ongoing transcription.
    func cancel() {
        Logger.shared.info("Cancelling transcription", component: "TRANSCRIPTION")
        pollingTask?.cancel()
        pollingTask = nil
        apply(.reset)
    }

    // MARK: - Polling

    private func startPolling(client: WhisperAPIClient, jobId: String, audioFileURL: URL) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }

            // Let the server register the job before the first poll
            try? await Task.sleep(nanoseconds: UInt64(Constants.Transcription.initialPollingDelay * 1_000_000_000))

            var pollCount = 0

            while !Task.isCancelled && pollCount < Constants.Transcription.maxPollingAttempts {
                do {
                    let jobDetail = try await client.getJobStatus(jobId: jobId)
                    let status = jobDetail.job.status

                    apply(.statusUpdated(status))

                    if let lastLog = jobDetail.job.lastLog {
                        apply(.progressMessage(lastLog))
                        Logger.shared.debug("Job log: \(lastLog)", component: "TRANSCRIPTION")
                    }

                    switch status {
                    case .completed:
                        Logger.shared.info("Job completed, downloading result…", component: "TRANSCRIPTION")
                        await downloadAndSaveResult(client: client, jobId: jobId, audioFileURL: audioFileURL)
                        return

                    case .failed:
                        Logger.shared.error("Job failed on server", component: "TRANSCRIPTION")
                        apply(.failed(L10n.transcriptionErrorJobFailed))
                        return

                    case .pending, .running:
                        break
                    }

                    try await Task.sleep(nanoseconds: UInt64(Constants.Transcription.pollingInterval * 1_000_000_000))
                    pollCount += 1
                } catch is CancellationError {
                    return
                } catch {
                    Logger.shared.warning("Polling error: \(error.localizedDescription)", component: "TRANSCRIPTION")
                    pollCount += 1
                    if pollCount < Constants.Transcription.maxPollingAttempts {
                        try? await Task.sleep(nanoseconds: UInt64(Constants.Transcription.pollingInterval * 1_000_000_000))
                    }
                }
            }

            if pollCount >= Constants.Transcription.maxPollingAttempts {
                Logger.shared.warning("Polling timeout", component: "TRANSCRIPTION")
                apply(.failed(L10n.transcriptionErrorTooLong))
            }
        }
    }

    private func downloadAndSaveResult(client: WhisperAPIClient, jobId: String, audioFileURL: URL) async {
        do {
            let transcription = try await client.downloadResult(jobId: jobId)
            let outputURL = getTranscriptionURL(for: audioFileURL)
            try transcription.write(to: outputURL, atomically: true, encoding: .utf8)

            Logger.shared.info("Transcription saved to: \(outputURL.path)", component: "TRANSCRIPTION")
            apply(.saved)

            // Show the success message briefly, then reset
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            apply(.reset)
        } catch {
            Logger.shared.error("Failed to save result: \(error.localizedDescription)", component: "TRANSCRIPTION")
            apply(.failed(L10n.transcriptionErrorSaveFailed(error.localizedDescription)))
        }
    }

    // MARK: - Parameters

    private var currentParameters: TranscriptionRequest {
        TranscriptionRequest(
            outputFormat: "txt",
            model: settings.whisperModel,
            language: settings.language,
            batchSize: 8,
            computeType: settings.computeType,
            diarize: true,
            nbSpeaker: settings.nbSpeaker,
            debug: false
        )
    }

    // MARK: - File Helpers

    /// Transcription file URL for an audio file (same directory, `.txt`).
    func getTranscriptionURL(for audioURL: URL) -> URL {
        let directory = audioURL.deletingLastPathComponent()
        let filename = audioURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(filename).txt")
    }

    /// Check if a transcription already exists for an audio file.
    func transcriptionExists(for audioURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: getTranscriptionURL(for: audioURL).path)
    }

    /// Read an existing transcription.
    func readTranscription(for audioURL: URL) -> String? {
        do {
            return try String(contentsOf: getTranscriptionURL(for: audioURL), encoding: .utf8)
        } catch {
            Logger.shared.warning("Failed to read existing transcription: \(error.localizedDescription)", component: "TRANSCRIPTION")
            return nil
        }
    }

    // MARK: - Reducer Bridge

    private func apply(_ event: TranscriptionEvent) {
        TranscriptionStateReducer.reduce(&state, event)
    }
}
