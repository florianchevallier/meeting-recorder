import Foundation

/// Pure endpoint logic for the Whisper API.
enum EndpointResolver {

    /// Candidate paths for starting a transcription, tried in order.
    static let startEndpointCandidates = ["process", "jobs", "transcriptions", "transcribe"]

    /// Trim whitespace and trailing slashes.
    static func sanitizeBaseURL(_ url: String) -> String {
        var sanitized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while sanitized.hasSuffix("/") {
            sanitized.removeLast()
        }
        return sanitized
    }

    /// Full candidate URLs for the start endpoint, in fallback order.
    static func startEndpoints(baseURL: String) -> [URL] {
        startEndpointCandidates.compactMap { endpointURL(baseURL: baseURL, path: $0) }
    }

    static func jobStatusURL(baseURL: String, jobId: String) -> URL? {
        endpointURL(baseURL: baseURL, path: "jobs/\(jobId)")
    }

    static func jobResultURL(baseURL: String, jobId: String) -> URL? {
        endpointURL(baseURL: baseURL, path: "jobs/\(jobId)/result")
    }

    /// Only a 404 means "wrong endpoint, try the next candidate".
    /// Any other status is a real answer (success or error) and stops the fallback.
    static func shouldTryNextEndpoint(statusCode: Int) -> Bool {
        statusCode == 404
    }

    private static func endpointURL(baseURL: String, path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(baseURL)/\(trimmedPath)")
    }
}
