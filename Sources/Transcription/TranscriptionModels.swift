import Foundation

// MARK: - API Request Models

/// Request body for starting audio transcription
struct TranscriptionRequest: Codable, Sendable {
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
struct TranscriptionJobResponse: Codable, Sendable {
    let success: Bool
    let message: String
    let jobId: String
    let links: JobLinks

    struct JobLinks: Codable, Sendable {
        let status: String
        let logs: String
        let logsStream: String
        let result: String
    }
}

/// Job status values
enum JobStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
}

/// Response for job status check
struct JobDetailResponse: Codable, Sendable {
    let success: Bool
    let job: JobDetail

    struct JobDetail: Codable, Sendable {
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
struct JobLogsResponse: Codable, Sendable {
    let success: Bool
    let logs: [String]
}

/// Error response from API
struct APIErrorResponse: Codable, Sendable {
    let success: Bool
    let error: String
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case badRequest(String)
    case serverError(String)
    case unexpectedStatusCode(Int)
    case jobNotFound
    case jobNotCompleted
    case resultNotFound
    case missingBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.apiErrorInvalidURL
        case .invalidResponse:
            return L10n.apiErrorInvalidResponse
        case .invalidData:
            return L10n.apiErrorInvalidData
        case .badRequest(let message):
            return L10n.apiErrorBadRequest(message)
        case .serverError(let message):
            return L10n.apiErrorServerError(message)
        case .unexpectedStatusCode(let code):
            return L10n.apiErrorUnexpectedStatus(code)
        case .jobNotFound:
            return L10n.apiErrorJobNotFound
        case .jobNotCompleted:
            return L10n.apiErrorJobNotCompleted
        case .resultNotFound:
            return L10n.apiErrorResultNotFound
        case .missingBaseURL:
            return L10n.apiErrorMissingBaseURL
        }
    }
}
