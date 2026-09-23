import Foundation

/// Writes the multipart/form-data body of the transcription upload to a file,
/// streaming the audio in chunks so a long recording never sits in memory.
enum MultipartBuilder {

    static let audioFieldName = "audio"
    private static let chunkSize = 1 << 20

    static func writeBody(
        audioFileURL: URL,
        parameters: TranscriptionRequest,
        boundary: String,
        to bodyURL: URL
    ) throws {
        guard FileManager.default.createFile(atPath: bodyURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: bodyURL.path])
        }
        let output = try FileHandle(forWritingTo: bodyURL)
        defer { try? output.close() }

        // Parameter parts — order fixed for deterministic output (tests)
        for (key, value) in parameters.formFields {
            try output.write(contentsOf: Data("--\(boundary)\r\n".utf8))
            try output.write(contentsOf: Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            try output.write(contentsOf: Data("\(value)\r\n".utf8))
        }

        // Audio file part
        let filename = audioFileURL.lastPathComponent
        let mimeType = "audio/\(audioFileURL.pathExtension)"
        try output.write(contentsOf: Data("--\(boundary)\r\n".utf8))
        try output.write(
            contentsOf: Data(
                "Content-Disposition: form-data; name=\"\(audioFieldName)\"; filename=\"\(filename)\"\r\n".utf8))
        try output.write(contentsOf: Data("Content-Type: \(mimeType)\r\n\r\n".utf8))

        let input = try FileHandle(forReadingFrom: audioFileURL)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
        }

        try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
    }
}
