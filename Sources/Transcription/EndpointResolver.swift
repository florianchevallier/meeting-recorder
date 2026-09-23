import Foundation

/// Pure endpoint logic for the WhisperX API. The base URL ends with the API
/// prefix (`https://host/api`).
enum EndpointResolver {

    /// Trim whitespace and trailing slashes.
    static func sanitizeBaseURL(_ url: String) -> String {
        var sanitized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while sanitized.hasSuffix("/") {
            sanitized.removeLast()
        }
        return sanitized
    }

    static func processURL(baseURL: String) -> URL? {
        endpointURL(baseURL: baseURL, path: "process")
    }

    /// Status (GET) and deletion (DELETE) of a job.
    static func jobURL(baseURL: String, jobId: String) -> URL? {
        endpointURL(baseURL: baseURL, path: "jobs/\(jobId)")
    }

    static func jobResultURL(baseURL: String, jobId: String) -> URL? {
        endpointURL(baseURL: baseURL, path: "jobs/\(jobId)/result")
    }

    private static func endpointURL(baseURL: String, path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(baseURL)/\(trimmedPath)")
    }
}
