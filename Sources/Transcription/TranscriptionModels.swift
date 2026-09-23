import Foundation

// MARK: - API Request Models

/// Form fields of `POST /process`. Optional values are left out of the form
/// so the server applies its own default.
struct TranscriptionRequest: Sendable, Equatable {
    var outputFormat = "json"
    var model: String
    var language: String
    var batchSize = 8
    var computeType: String
    var diarize = true
    /// Exact speaker count; takes precedence over the range on the server.
    var nbSpeaker: Int?
    var minSpeakers: Int?
    var maxSpeakers: Int?
    var initialPrompt: String?
    var debug = false

    /// Ordered `(name, value)` pairs, optional fields only when set.
    var formFields: [(String, String)] {
        var fields: [(String, String)] = [
            ("outputFormat", outputFormat),
            ("model", model),
            ("language", language),
            ("batchSize", String(batchSize)),
            ("computeType", computeType),
            ("diarize", String(diarize)),
        ]
        if let nbSpeaker { fields.append(("nbSpeaker", String(nbSpeaker))) }
        if let minSpeakers { fields.append(("minSpeakers", String(minSpeakers))) }
        if let maxSpeakers { fields.append(("maxSpeakers", String(maxSpeakers))) }
        if let initialPrompt, !initialPrompt.isEmpty { fields.append(("initialPrompt", initialPrompt)) }
        fields.append(("debug", String(debug)))
        return fields
    }
}

/// Server job in flight for a recording (`<name>.transcription-job.json`):
/// lets a relaunch resume polling instead of uploading again.
struct PendingTranscriptionJob: Codable, Sendable, Equatable {
    let jobId: String
    let submittedAt: Date

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> PendingTranscriptionJob {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PendingTranscriptionJob.self, from: Data(contentsOf: url))
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
    case unauthorized

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
        case .unauthorized:
            return L10n.apiErrorUnauthorized
        }
    }
}
