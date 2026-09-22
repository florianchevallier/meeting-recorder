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

    @Test("Process, job and result URLs hang off the API prefix")
    func urls() {
        let base = "https://api.example.com/api"
        #expect(EndpointResolver.processURL(baseURL: base)?.absoluteString == "https://api.example.com/api/process")
        #expect(
            EndpointResolver.jobURL(baseURL: base, jobId: "abc")?.absoluteString
                == "https://api.example.com/api/jobs/abc")
        #expect(
            EndpointResolver.jobResultURL(baseURL: base, jobId: "abc")?.absoluteString
                == "https://api.example.com/api/jobs/abc/result"
        )
    }
}
