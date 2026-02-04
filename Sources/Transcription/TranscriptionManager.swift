//
//  TranscriptionManager.swift
//  MeetingRecorder
//
//  Orchestrates the transcription workflow
//

import Foundation

/// Manages the complete transcription workflow
@MainActor
final class TranscriptionManager: ObservableObject {

    // MARK: - Properties

    @Published var state = TranscriptionState()

    private var apiClient: WhisperAPIClient
    private var pollingTask: Task<Void, Never>?

    // Get parameters from settings
    private var currentParameters: TranscriptionRequest {
        let settings = SettingsManager.shared
        return TranscriptionRequest(
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

    // MARK: - Initialization

    init() {
        // Initialize with settings
        let settings = SettingsManager.shared
        self.apiClient = WhisperAPIClient(baseURL: settings.apiBaseURL)
    }

    // MARK: - Public Methods

    /// Start transcription of a recorded audio file
    func transcribe(audioFileURL: URL) async {
        Logger.shared.log("🎤 [TRANSCRIPTION] Starting transcription for: \(audioFileURL.lastPathComponent)")

        do {
            // Reinitialize API client with latest settings
            let settings = SettingsManager.shared
            self.apiClient = WhisperAPIClient(baseURL: settings.apiBaseURL)

            // Start the transcription job
            let jobResponse = try await apiClient.startTranscription(
                audioFileURL: audioFileURL,
                parameters: currentParameters
            )

            state.startTranscription(jobId: jobResponse.jobId)
            Logger.shared.log("✅ [TRANSCRIPTION] Job created: \(jobResponse.jobId)")

            // Start polling for status
            await pollJobStatus(jobId: jobResponse.jobId, audioFileURL: audioFileURL)

        } catch {
            Logger.shared.log("❌ [TRANSCRIPTION] Failed to start: \(error.localizedDescription)")
            state.setError(error.localizedDescription)
        }
    }

    /// Cancel ongoing transcription
    func cancelTranscription() {
        Logger.shared.log("🛑 [TRANSCRIPTION] Cancelling transcription")
        pollingTask?.cancel()
        state.reset()
    }

    // MARK: - Private Methods

    private func pollJobStatus(jobId: String, audioFileURL: URL) async {
        pollingTask = Task {
            // Wait a bit before first poll to let the server register the job
            Logger.shared.log("⏳ [TRANSCRIPTION] Waiting 2s before first status check...")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            var pollCount = 0
            let maxPolls = 360 // 30 minutes max (5s interval)

            while !Task.isCancelled && pollCount < maxPolls {
                do {
                    let jobDetail = try await apiClient.getJobStatus(jobId: jobId)
                    let status = jobDetail.job.status

                    // Update state
                    state.updateStatus(status)

                    if let lastLog = jobDetail.job.lastLog {
                        state.updateProgress(lastLog)
                        Logger.shared.log("📝 [TRANSCRIPTION] \(lastLog)")
                    }

                    // Check if job is finished
                    switch status {
                    case .completed:
                        Logger.shared.log("✅ [TRANSCRIPTION] Job completed, downloading result...")
                        await downloadAndSaveResult(jobId: jobId, audioFileURL: audioFileURL)
                        return

                    case .failed:
                        Logger.shared.log("❌ [TRANSCRIPTION] Job failed")
                        state.setError("La transcription a échoué")
                        return

                    case .pending, .running:
                        // Continue polling
                        break
                    }

                    // Wait 5 seconds before next poll
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    pollCount += 1

                } catch {
                    Logger.shared.log("⚠️ [TRANSCRIPTION] Polling error: \(error.localizedDescription)")

                    // Retry on network errors
                    if pollCount < maxPolls {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        pollCount += 1
                    } else {
                        state.setError("Timeout lors de la vérification du statut")
                        return
                    }
                }
            }

            if pollCount >= maxPolls {
                Logger.shared.log("⏱️ [TRANSCRIPTION] Polling timeout")
                state.setError("La transcription prend trop de temps")
            }
        }
    }

    private func downloadAndSaveResult(jobId: String, audioFileURL: URL) async {
        do {
            // Download transcription text
            let transcription = try await apiClient.downloadResult(jobId: jobId)

            // Generate output file path
            let outputURL = generateOutputURL(from: audioFileURL)

            // Save to file
            try transcription.write(to: outputURL, atomically: true, encoding: .utf8)

            Logger.shared.log("💾 [TRANSCRIPTION] Saved to: \(outputURL.path)")
            state.updateProgress("✅ Transcription sauvegardée")

            // Reset state after short delay to show success message
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state.reset()

        } catch {
            Logger.shared.log("❌ [TRANSCRIPTION] Failed to save result: \(error.localizedDescription)")
            state.setError("Échec de la sauvegarde: \(error.localizedDescription)")
        }
    }

    private func generateOutputURL(from audioURL: URL) -> URL {
        // Replace .m4a extension with .txt
        let directory = audioURL.deletingLastPathComponent()
        let filename = audioURL.deletingPathExtension().lastPathComponent
        let outputFilename = "\(filename).txt"

        return directory.appendingPathComponent(outputFilename)
    }
}

// MARK: - Convenience Methods

extension TranscriptionManager {

    /// Check if a transcription already exists for an audio file
    func transcriptionExists(for audioURL: URL) -> Bool {
        let transcriptionURL = generateOutputURL(from: audioURL)
        return FileManager.default.fileExists(atPath: transcriptionURL.path)
    }

    /// Get transcription file URL for an audio file
    func getTranscriptionURL(for audioURL: URL) -> URL {
        return generateOutputURL(from: audioURL)
    }

    /// Read existing transcription
    func readTranscription(for audioURL: URL) -> String? {
        let transcriptionURL = generateOutputURL(from: audioURL)

        do {
            return try String(contentsOf: transcriptionURL, encoding: .utf8)
        } catch {
            Logger.shared.log("⚠️ [TRANSCRIPTION] Failed to read existing transcription: \(error.localizedDescription)")
            return nil
        }
    }
}
