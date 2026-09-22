import os
import Foundation

/// HTTP client for the WhisperX transcription API. Stateless and `Sendable`.
struct WhisperAPIClient: Sendable {

    let baseURL: String
    private let apiKey: String?
    private let session: URLSession

    init(baseURL: String, apiKey: String? = nil, session: URLSession? = nil) {
        self.baseURL = EndpointResolver.sanitizeBaseURL(baseURL)
        self.apiKey = apiKey.flatMap { $0.isEmpty ? nil : $0 }
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

    /// Upload the audio file. The multipart body is written to a temporary file
    /// and streamed from disk.
    func startTranscription(
        audioFileURL: URL,
        parameters: TranscriptionRequest
    ) async throws -> TranscriptionJobResponse {
        var request = try makeRequest(EndpointResolver.processURL(baseURL: baseURL), method: "POST")

        let boundary = "Boundary-\(UUID().uuidString)"
        let bodyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meety-upload-\(UUID().uuidString).multipart")
        try MultipartBuilder.writeBody(
            audioFileURL: audioFileURL, parameters: parameters, boundary: boundary, to: bodyURL)
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let bodySize = (try? bodyURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        Log.transcription.info("Uploading audio (\(bodySize / 1024) KB) to \(request.url?.absoluteString ?? "?")")

        let (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        let statusCode = try Self.statusCode(of: response)
        Log.transcription.debug("Start response status: \(statusCode)")

        switch statusCode {
        case 202:  // Accepted — job started
            let jobResponse = try JSONDecoder().decode(TranscriptionJobResponse.self, from: data)
            Log.transcription.info("Job created: \(jobResponse.jobId)")
            return jobResponse

        case 400:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.badRequest(errorResponse?.error ?? "Invalid request")

        case 401:
            throw APIError.unauthorized

        case 500:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error ?? "Internal server error")

        default:
            throw APIError.unexpectedStatusCode(statusCode)
        }
    }

    // MARK: - Job Status

    func getJobStatus(jobId: String) async throws -> JobDetailResponse {
        let request = try makeRequest(EndpointResolver.jobURL(baseURL: baseURL, jobId: jobId), method: "GET")
        let (data, response) = try await session.data(for: request)

        switch try Self.statusCode(of: response) {
        case 200:
            return try JSONDecoder().decode(JobDetailResponse.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.jobNotFound
        case let code:
            if let body = String(data: data, encoding: .utf8) {
                Log.transcription.warning("Unexpected job status response (\(code)): \(body)")
            }
            throw APIError.unexpectedStatusCode(code)
        }
    }

    // MARK: - Download Result

    /// Raw result body (JSON when the job was started with `outputFormat=json`).
    func downloadResult(jobId: String) async throws -> Data {
        let request = try makeRequest(EndpointResolver.jobResultURL(baseURL: baseURL, jobId: jobId), method: "GET")
        let (data, response) = try await session.data(for: request)

        switch try Self.statusCode(of: response) {
        case 200:
            Log.transcription.info("Result downloaded: \(data.count) bytes")
            return data
        case 400:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            if let error = errorResponse?.error, error.contains("pas terminé") {
                throw APIError.jobNotCompleted
            }
            throw APIError.badRequest(errorResponse?.error ?? "Bad request")
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.resultNotFound
        case let code:
            throw APIError.unexpectedStatusCode(code)
        }
    }

    // MARK: - Delete Job

    /// Removes the job, its audio and its result from the server. A job the
    /// server no longer knows counts as deleted.
    func deleteJob(jobId: String) async throws {
        let request = try makeRequest(EndpointResolver.jobURL(baseURL: baseURL, jobId: jobId), method: "DELETE")
        let (_, response) = try await session.data(for: request)

        switch try Self.statusCode(of: response) {
        case 200, 204, 404:
            return
        case 401:
            throw APIError.unauthorized
        case let code:
            throw APIError.unexpectedStatusCode(code)
        }
    }

    // MARK: - Helpers

    private func makeRequest(_ url: URL?, method: String) throws -> URLRequest {
        guard !baseURL.isEmpty else { throw APIError.missingBaseURL }
        guard let url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Free ngrok tunnels answer an HTML interstitial without this header.
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: Constants.Transcription.apiKeyHeader)
        }
        return request
    }

    private static func statusCode(of response: URLResponse) throws -> Int {
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return httpResponse.statusCode
    }
}
