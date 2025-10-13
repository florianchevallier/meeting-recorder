//
//  TranscriptionModels.swift
//  MeetingRecorder
//
//  Models for Whisper API integration
//

import Foundation

// MARK: - API Request Models

/// Request body for starting audio transcription
struct TranscriptionRequest: Codable {
    let outputFormat: String
    let model: String
    let language: String
    let batchSize: Int
    let computeType: String
    let diarize: Bool
    let nbSpeaker: Int
    let debug: Bool

    init(
        outputFormat: String = "txt",
        model: String = "large-v3",
        language: String = "fr",
        batchSize: Int = 8,
        computeType: String = "float16",
        diarize: Bool = true,
        nbSpeaker: Int = 2,
        debug: Bool = false
    ) {
        self.outputFormat = outputFormat
        self.model = model
        self.language = language
        self.batchSize = batchSize
        self.computeType = computeType
        self.diarize = diarize
        self.nbSpeaker = nbSpeaker
        self.debug = debug
    }
}

// MARK: - API Response Models

/// Response when starting a new transcription job
struct TranscriptionJobResponse: Codable {
    let success: Bool
    let message: String
    let jobId: String
    let links: JobLinks

    struct JobLinks: Codable {
        let status: String
        let logs: String
        let logsStream: String
        let result: String
    }
}

/// Job status values
enum JobStatus: String, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
}

/// Response for job status check
struct JobDetailResponse: Codable {
    let success: Bool
    let job: JobDetail

    struct JobDetail: Codable {
        let id: String
        let status: JobStatus
        let createdAt: String
        let updatedAt: String
        let lastLog: String?
        let outputPath: String?
        let outputFormat: String?
        let logs: [String]?
    }
}

/// Response for job logs
struct JobLogsResponse: Codable {
    let success: Bool
    let logs: [String]
}

/// Error response from API
struct APIErrorResponse: Codable {
    let success: Bool
    let error: String
}

// MARK: - Internal Status Model

/// Internal model for tracking transcription state
@MainActor
class TranscriptionState: ObservableObject {
    @Published var isTranscribing: Bool = false
    @Published var currentJobId: String?
    @Published var status: JobStatus = .pending
    @Published var lastLog: String?
    @Published var progress: String = ""
    @Published var error: String?

    func reset() {
        isTranscribing = false
        currentJobId = nil
        status = .pending
        lastLog = nil
        progress = ""
        error = nil
    }

    func startTranscription(jobId: String) {
        // Don't overwrite progress if already set (e.g., "Upload vers API...")
        if progress.isEmpty || !isTranscribing {
            self.progress = "🎤 Transcription démarrée..."
        }
        self.isTranscribing = true
        self.currentJobId = jobId
        self.status = .pending
        self.error = nil
    }

    func updateProgress(_ message: String) {
        self.progress = message
        self.lastLog = message
    }

    func updateStatus(_ newStatus: JobStatus) {
        self.status = newStatus
        switch newStatus {
        case .pending:
            self.progress = "⏳ En attente..."
        case .running:
            self.progress = "🔄 Transcription en cours..."
        case .completed:
            self.progress = "✅ Transcription terminée"
            self.isTranscribing = false
        case .failed:
            self.progress = "❌ Échec de la transcription"
            self.isTranscribing = false
        }
    }

    func setError(_ message: String) {
        self.error = message
        self.progress = "❌ Erreur: \(message)"
        self.isTranscribing = false
    }
}
