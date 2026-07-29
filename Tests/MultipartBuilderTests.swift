import Testing
import Foundation
@testable import MeetingRecorder

@Suite("MultipartBuilder")
struct MultipartBuilderTests {

    @Test("Body contains the audio part and all 8 parameters")
    func bodyContents() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).m4a")
        try Data("fake-audio-bytes".utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let parameters = TranscriptionRequest(
            outputFormat: "txt",
            model: "large-v3",
            language: "fr",
            batchSize: 8,
            computeType: "float16",
            diarize: true,
            nbSpeaker: 2,
            debug: false
        )

        let body = try MultipartBuilder.makeBody(
            audioFileURL: tempFile,
            parameters: parameters,
            boundary: "TestBoundary"
        )
        let bodyString = String(decoding: body, as: UTF8.self)

        // Audio part
        #expect(bodyString.contains("name=\"audio\""))
        #expect(bodyString.contains("filename=\"\(tempFile.lastPathComponent)\""))
        #expect(bodyString.contains("Content-Type: audio/m4a"))
        #expect(bodyString.contains("fake-audio-bytes"))

        // All 8 parameter fields
        for field in ["outputFormat", "model", "language", "batchSize", "computeType", "diarize", "nbSpeaker", "debug"] {
            #expect(bodyString.contains("name=\"\(field)\""), "missing field \(field)")
        }

        // Values
        #expect(bodyString.contains("large-v3"))
        #expect(bodyString.contains("float16"))

        // Boundaries
        #expect(bodyString.hasPrefix("--TestBoundary\r\n"))
        #expect(bodyString.hasSuffix("--TestBoundary--\r\n"))
    }
}
