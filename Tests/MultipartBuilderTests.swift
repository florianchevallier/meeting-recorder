import Testing
import Foundation
@testable import MeetingRecorder

@Suite("MultipartBuilder")
struct MultipartBuilderTests {

    private func body(for parameters: TranscriptionRequest) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let audio = directory.appendingPathComponent("meeting.m4a")
        try Data("fake-audio-bytes".utf8).write(to: audio)
        let bodyURL = directory.appendingPathComponent("body")

        try MultipartBuilder.writeBody(
            audioFileURL: audio, parameters: parameters, boundary: "TestBoundary", to: bodyURL)
        return String(decoding: try Data(contentsOf: bodyURL), as: UTF8.self)
    }

    @Test("Body streams the audio part after the parameters, between boundaries")
    func bodyContents() throws {
        let bodyString = try body(
            for: TranscriptionRequest(
                model: "large-v3", language: "fr", computeType: "float16",
                minSpeakers: 1, maxSpeakers: 4, initialPrompt: "Point hebdo. Alice, Bob"))

        #expect(bodyString.contains("name=\"audio\"; filename=\"meeting.m4a\""))
        #expect(bodyString.contains("Content-Type: audio/m4a\r\n\r\nfake-audio-bytes\r\n"))
        for field in [
            "outputFormat", "model", "language", "batchSize", "computeType", "diarize", "minSpeakers", "maxSpeakers",
            "initialPrompt", "debug",
        ] {
            #expect(bodyString.contains("name=\"\(field)\""), "missing field \(field)")
        }
        #expect(bodyString.contains("name=\"outputFormat\"\r\n\r\njson\r\n"))
        #expect(bodyString.contains("name=\"maxSpeakers\"\r\n\r\n4\r\n"))
        #expect(bodyString.hasPrefix("--TestBoundary\r\n"))
        #expect(bodyString.hasSuffix("\r\n--TestBoundary--\r\n"))
    }

    @Test("Unset optional fields are left out so the server applies its default")
    func optionalFields() throws {
        let bodyString = try body(for: TranscriptionRequest(model: "large-v3", language: "fr", computeType: "int8"))
        #expect(!bodyString.contains("nbSpeaker"))
        #expect(!bodyString.contains("minSpeakers"))
        #expect(!bodyString.contains("maxSpeakers"))
        #expect(!bodyString.contains("initialPrompt"))
    }
}
