import Foundation

/// `transcribe_file` MCP tool: sends any local audio/video file to the WhisperX API set in Meety's
/// settings (URL, key from the keychain, model, vocabulary), waits for the result and writes
/// `.transcript.json` + `.txt` next to the file, like for a recording. Blocks the stdio loop until done.
/// ponytail: a network error during polling stops the call; the `.transcription-job.json` sidecar
/// is kept so calling again resumes the job instead of re-uploading. Retry in place if that bites.
enum MCPTranscriber {

    /// Transcript text (or error message) for the file at `path`, and whether it is an error.
    /// Must run on the main thread unless the file already has a transcript (settings are main-actor).
    static func transcribe(path: String) -> (String, Bool) {
        // Trust boundary: the path comes from the LLM.
        let expanded =
            path.hasPrefix("~/") ? FileManager.default.homeDirectoryForCurrentUser.path + path.dropFirst() : path
        var isDirectory: ObjCBool = false
        guard expanded.hasPrefix("/"),
            FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), !isDirectory.boolValue
        else { return ("File not found (absolute path expected): \(path)", true) }
        let file = URL(fileURLWithPath: expanded)
        let files = RecordingFiles(audio: file)
        guard files.transcriptText != file, files.transcriptJSON != file else { return ("Not an audio file", true) }

        // Already transcribed by Meety (the `.json` proves the `.txt` is ours, not an unrelated note).
        if FileManager.default.fileExists(atPath: files.transcriptJSON.path),
            let text = try? String(contentsOf: files.transcriptText, encoding: .utf8)
        {
            return (text, false)
        }

        let (client, parameters) = MainActor.assumeIsolated { () -> (WhisperAPIClient, TranscriptionRequest) in
            let settings = SettingsStore()
            let hints = TranscriptionHints.make(
                event: nil, glossary: settings.transcriptionGlossary, maxSpeakers: settings.nbSpeaker,
                packTerms: VocabularyPack.terms(
                    for: settings.vocabularyPacks, custom: settings.customVocabularyPacks))
            return (
                WhisperAPIClient(
                    baseURL: settings.apiBaseURL,
                    apiKey: KeychainStore.string(for: KeychainStore.transcriptionAPIKeyAccount)),
                TranscriptionRequest(
                    model: settings.whisperModel, language: settings.language, computeType: settings.computeType,
                    minSpeakers: hints.minSpeakers, maxSpeakers: hints.maxSpeakers, initialPrompt: hints.initialPrompt)
            )
        }

        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            box.result = await run(files: files, client: client, parameters: parameters)
            done.signal()
        }
        done.wait()
        return box.result
    }

    private static func run(
        files: RecordingFiles, client: WhisperAPIClient, parameters: TranscriptionRequest
    ) async -> (String, Bool) {
        do {
            let jobId: String
            if let pending = try? PendingTranscriptionJob.read(from: files.pendingJob) {
                jobId = pending.jobId
            } else {
                jobId = try await client.startTranscription(audioFileURL: files.audio, parameters: parameters).jobId
                try PendingTranscriptionJob(jobId: jobId, submittedAt: Date()).write(to: files.pendingJob)
            }

            var status = JobStatus.pending
            for _ in 0..<Constants.Transcription.maxPollingAttempts where status != .completed {
                try await Task.sleep(for: .seconds(Constants.Transcription.pollingInterval))
                status = try await client.getJobStatus(jobId: jobId).job.status
                if status == .failed { throw TranscriptionFailure.jobFailed }
            }
            guard status == .completed else { throw TranscriptionFailure.tooLong }

            let data = try await client.downloadResult(jobId: jobId)
            _ = try Transcript.decode(data)  // never save garbage
            try data.write(to: files.transcriptJSON, options: .atomic)
            try TranscriptFiles.writeText(for: files.audio)
            try? FileManager.default.removeItem(at: files.pendingJob)
            try? await client.deleteJob(jobId: jobId)
            let text = try String(contentsOf: files.transcriptText, encoding: .utf8)
            return ("Saved to \(files.transcriptText.path)\n\n" + text, false)
        } catch {
            // Same rule as the app: a network failure keeps the job so a retry resumes it.
            if !(error is URLError) { try? FileManager.default.removeItem(at: files.pendingJob) }
            return ("Transcription failed: \(error.localizedDescription)", true)
        }
    }

    /// Hands the detached task's result back to the blocked stdio thread (the semaphore orders the access).
    private final class ResultBox: @unchecked Sendable {
        var result = ("", true)
    }
}
