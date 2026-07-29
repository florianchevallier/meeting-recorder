import Foundation

/// Builds the multipart/form-data body for the transcription upload.
/// Pure and force-unwrap-free (`Data(String.utf8)` never fails).
enum MultipartBuilder {

    static let audioFieldName = "audio"

    static func makeBody(
        audioFileURL: URL,
        parameters: TranscriptionRequest,
        boundary: String
    ) throws -> Data {
        var body = Data()

        // Audio file part
        let audioData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        let mimeType = "audio/\(audioFileURL.pathExtension)"

        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(audioFieldName)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n".utf8))

        // Parameter parts — order fixed for deterministic output (tests)
        let fields: [(String, String)] = [
            ("outputFormat", parameters.outputFormat),
            ("model", parameters.model),
            ("language", parameters.language),
            ("batchSize", String(parameters.batchSize)),
            ("computeType", parameters.computeType),
            ("diarize", String(parameters.diarize)),
            ("nbSpeaker", String(parameters.nbSpeaker)),
            ("debug", String(parameters.debug))
        ]

        for (key, value) in fields {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }
}
