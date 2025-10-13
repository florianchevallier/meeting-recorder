//
//  WhisperAPIClient.swift
//  MeetingRecorder
//
//  HTTP client for Whisper transcription API
//

import Foundation

/// Client for interacting with Whisper transcription API
class WhisperAPIClient {

    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession
    private static let startEndpointCandidates = [
        "process",
        "jobs",
        "transcriptions",
        "transcribe"
    ]

    // MARK: - Initialization

    init(baseURL: String = "") {
        self.baseURL = WhisperAPIClient.sanitizeBaseURL(baseURL)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 minutes for file upload
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Start transcription of an audio file
    func startTranscription(
        audioFileURL: URL,
        parameters: TranscriptionRequest
    ) async throws -> TranscriptionJobResponse {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }

        // Prepare multipart form data once, reused for each candidate endpoint
        let boundary = "Boundary-\(UUID().uuidString)"
        let httpBody = try createMultipartBody(
            audioFileURL: audioFileURL,
            parameters: parameters,
            boundary: boundary
        )

        var lastError: Error = APIError.invalidURL

        for path in Self.startEndpointCandidates {
            guard let url = endpointURL(for: path) else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            Logger.shared.log("📤 [WHISPER_API] Uploading audio file to \(url.absoluteString)")
            Logger.shared.log("📊 [WHISPER_API] File size: \(httpBody.count / 1024) KB")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                Logger.shared.log("📥 [WHISPER_API] Response status: \(httpResponse.statusCode)")

                switch httpResponse.statusCode {
                case 202: // Accepted - job started
                    let jobResponse = try JSONDecoder().decode(TranscriptionJobResponse.self, from: data)
                    Logger.shared.log("✅ [WHISPER_API] Job created: \(jobResponse.jobId)")
                    return jobResponse

                case 400: // Bad request
                    let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                    throw APIError.badRequest(errorResponse?.error ?? "Invalid request")

                case 404:
                    Logger.shared.log("⚠️ [WHISPER_API] Endpoint \(url.absoluteString) not found (404). Trying fallback...")
                    lastError = APIError.unexpectedStatusCode(404)
                    continue // Try next candidate endpoint

                case 500: // Server error
                    let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                    throw APIError.serverError(errorResponse?.error ?? "Internal server error")

                default:
                    throw APIError.unexpectedStatusCode(httpResponse.statusCode)
                }
            } catch let error as APIError {
                // Propagate known API errors (other than 404 which is handled above)
                if case .unexpectedStatusCode(404) = error {
                    // Already handled in switch (should not reach here), but keep for safety
                    lastError = error
                    continue
                }
                throw error
            } catch {
                // Network-level errors, propagate directly
                throw error
            }
        }

        Logger.shared.log("❌ [WHISPER_API] No transcription endpoint responded successfully. Verify your API base URL in the settings.")
        throw lastError
    }

    /// Get job status
    func getJobStatus(jobId: String) async throws -> JobDetailResponse {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }

        let endpoint = "\(baseURL)/jobs/\(jobId)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        Logger.shared.log("🔍 [WHISPER_API] Polling job status: \(endpoint)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        Logger.shared.log("📥 [WHISPER_API] Job status response: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            let jobDetail = try JSONDecoder().decode(JobDetailResponse.self, from: data)
            Logger.shared.log("✅ [WHISPER_API] Job status: \(jobDetail.job.status.rawValue)")
            return jobDetail

        case 404:
            if let responseBody = String(data: data, encoding: .utf8) {
                Logger.shared.log("❌ [WHISPER_API] 404 response body: \(responseBody)")
            }
            throw APIError.jobNotFound

        default:
            if let responseBody = String(data: data, encoding: .utf8) {
                Logger.shared.log("⚠️ [WHISPER_API] Unexpected response (\(httpResponse.statusCode)): \(responseBody)")
            }
            throw APIError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    /// Download transcription result
    func downloadResult(jobId: String) async throws -> String {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }

        let endpoint = "\(baseURL)/jobs/\(jobId)/result"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        Logger.shared.log("📥 [WHISPER_API] Downloading result for job \(jobId)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let transcription = String(data: data, encoding: .utf8) else {
                throw APIError.invalidData
            }
            Logger.shared.log("✅ [WHISPER_API] Result downloaded: \(transcription.count) characters")
            return transcription

        case 400:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            if let error = errorResponse?.error, error.contains("pas terminé") {
                throw APIError.jobNotCompleted
            }
            throw APIError.badRequest(errorResponse?.error ?? "Bad request")

        case 404:
            throw APIError.resultNotFound

        default:
            throw APIError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    // MARK: - Private Methods

    private func createMultipartBody(
        audioFileURL: URL,
        parameters: TranscriptionRequest,
        boundary: String
    ) throws -> Data {
        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        let mimeType = "audio/\(audioFileURL.pathExtension)"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add parameters
        let paramDict: [String: Any] = [
            "outputFormat": parameters.outputFormat,
            "model": parameters.model,
            "language": parameters.language,
            "batchSize": parameters.batchSize,
            "computeType": parameters.computeType,
            "diarize": parameters.diarize,
            "nbSpeaker": parameters.nbSpeaker,
            "debug": parameters.debug
        ]

        for (key, value) in paramDict {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }
}

// MARK: - Helpers

private extension WhisperAPIClient {
    static func sanitizeBaseURL(_ url: String) -> String {
        var sanitized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while sanitized.hasSuffix("/") {
            sanitized.removeLast()
        }
        return sanitized
    }

    func endpointURL(for path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)/\(trimmedPath)"
        return URL(string: urlString)
    }
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
            return "URL de l'API invalide"
        case .invalidResponse:
            return "Réponse de l'API invalide"
        case .invalidData:
            return "Données reçues invalides"
        case .badRequest(let message):
            return "Requête invalide: \(message)"
        case .serverError(let message):
            return "Erreur serveur: \(message)"
        case .unexpectedStatusCode(let code):
            return "Code HTTP inattendu: \(code)"
        case .jobNotFound:
            return "Job de transcription non trouvé"
        case .jobNotCompleted:
            return "Transcription pas encore terminée"
        case .resultNotFound:
            return "Résultat de transcription non trouvé"
        case .missingBaseURL:
            return "Configurez l'URL de l'API de transcription dans les paramètres"
        }
    }
}
