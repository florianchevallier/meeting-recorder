import Testing
import Foundation
@testable import MeetingRecorder

@Suite("EndpointResolver")
struct EndpointResolverTests {

    @Test("Base URL is sanitized: whitespace and trailing slashes removed")
    func sanitize() {
        #expect(EndpointResolver.sanitizeBaseURL("  https://api.example.com/  ") == "https://api.example.com")
        #expect(EndpointResolver.sanitizeBaseURL("https://api.example.com///") == "https://api.example.com")
        #expect(EndpointResolver.sanitizeBaseURL("https://api.example.com") == "https://api.example.com")
    }

    @Test("Start endpoints are generated in fallback order")
    func startEndpointOrder() {
        let urls = EndpointResolver.startEndpoints(baseURL: "https://api.example.com")
        #expect(urls.map(\.lastPathComponent) == ["process", "jobs", "transcriptions", "transcribe"])
        #expect(urls.first?.absoluteString == "https://api.example.com/process")
    }

    @Test("Only 404 continues the fallback")
    func fallbackRule() {
        #expect(EndpointResolver.shouldTryNextEndpoint(statusCode: 404))
        #expect(!EndpointResolver.shouldTryNextEndpoint(statusCode: 202))
        #expect(!EndpointResolver.shouldTryNextEndpoint(statusCode: 400))
        #expect(!EndpointResolver.shouldTryNextEndpoint(statusCode: 500))
    }

    @Test("Job status and result URLs")
    func jobURLs() {
        #expect(
            EndpointResolver.jobStatusURL(baseURL: "https://api.example.com", jobId: "abc")?.absoluteString
            == "https://api.example.com/jobs/abc"
        )
        #expect(
            EndpointResolver.jobResultURL(baseURL: "https://api.example.com", jobId: "abc")?.absoluteString
            == "https://api.example.com/jobs/abc/result"
        )
    }
}
