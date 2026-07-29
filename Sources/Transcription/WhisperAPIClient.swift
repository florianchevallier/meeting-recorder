import Foundation

/// HTTP client for the Whisper transcription API. Stateless and `Sendable`.
struct WhisperAPIClient: Sendable {

    let baseURL: String
    private let session: URLSession

    init(baseURL: String, session: URLSession? = nil) {
        self.baseURL = EndpointResolver.sanitizeBaseURL(baseURL)
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = Constants.Transcription.defaultTimeout
            config.timeoutIntervalForResource = Constants.Transcription.uploadTimeout
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Start Transcription

    /// Upload the audio file to the first candidate endpoint that does not 404.
    /// The multipart body is built once and reused across candidates.
    func startTranscription(
        audioFileURL: URL,
        parameters: TranscriptionRequest
    ) async throws -> TranscriptionJobResponse {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let httpBody = try MultipartBuilder.makeBody(
            audioFileURL: audioFileURL,
            parameters: parameters,
            boundary: boundary
        )

        var lastError: any Error = APIError.invalidURL

        for url in EndpointResolver.startEndpoints(baseURL: baseURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            Logger.shared.info("Uploading audio (\(httpBody.count / 1024) KB) to \(url.absoluteString)", component: "WHISPER_API")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                Logger.shared.debug("Start response status: \(httpResponse.statusCode)", component: "WHISPER_API")

                if EndpointResolver.shouldTryNextEndpoint(statusCode: httpResponse.statusCode) {
                    Logger.shared.info("Endpoint \(url.lastPathComponent) not found (404) — trying fallback", component: "WHISPER_API")
                    lastError = APIError.unexpectedStatusCode(404)
                    continue
                }

                switch httpResponse.statusCode {
                case 202: // Accepted — job started
                    let jobResponse = try JSONDecoder().decode(TranscriptionJobResponse.self, from: data)
                    Logger.shared.info("Job created: \(jobResponse.jobId)", component: "WHISPER_API")
                    return jobResponse

                case 400:
                    let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                    throw APIError.badRequest(errorResponse?.error ?? "Invalid request")

                case 500:
                    let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                    throw APIError.serverError(errorResponse?.error ?? "Internal server error")

                default:
                    throw APIError.unexpectedStatusCode(httpResponse.statusCode)
                }
            } catch let error as APIError {
                throw error
            }
        }

        Logger.shared.error("No transcription endpoint answered — check the API base URL in settings", component: "WHISPER_API")
        throw lastError
    }

    // MARK: - Job Status

    func getJobStatus(jobId: String) async throws -> JobDetailResponse {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }
        guard let url = EndpointResolver.jobStatusURL(baseURL: baseURL, jobId: jobId) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(JobDetailResponse.self, from: data)

        case 404:
            if let body = String(data: data, encoding: .utf8) {
                Logger.shared.error("Job status 404 body: \(body)", component: "WHISPER_API")
            }
            throw APIError.jobNotFound

        default:
            if let body = String(data: data, encoding: .utf8) {
                Logger.shared.warning("Unexpected job status response (\(httpResponse.statusCode)): \(body)", component: "WHISPER_API")
            }
            throw APIError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    // MARK: - Download Result

    func downloadResult(jobId: String) async throws -> String {
        guard !baseURL.isEmpty else {
            throw APIError.missingBaseURL
        }
        guard let url = EndpointResolver.jobResultURL(baseURL: baseURL, jobId: jobId) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let transcription = String(data: data, encoding: .utf8) else {
                throw APIError.invalidData
            }
            Logger.shared.info("Result downloaded: \(transcription.count) characters", component: "WHISPER_API")
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
}
