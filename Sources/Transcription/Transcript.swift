import Foundation

/// WhisperX JSON result (`outputFormat=json`): segments with word timings
/// and, after diarization, a `SPEAKER_xx` label on segments and words.
struct Transcript: Codable, Sendable, Equatable {
    struct Word: Codable, Sendable, Equatable {
        let word: String
        /// Missing for tokens the aligner could not place (numbers, symbols).
        let start: Double?
        let end: Double?
        let speaker: String?
    }

    struct Segment: Codable, Sendable, Equatable {
        let start: Double
        let end: Double
        let text: String
        let speaker: String?
        let words: [Word]?
    }

    let segments: [Segment]

    /// Speaker labels in order of first appearance.
    var speakers: [String] {
        var seen = Set<String>()
        return segments.compactMap(\.speaker).filter { seen.insert($0).inserted }
    }

    static func decode(_ data: Data) throws -> Transcript {
        try JSONDecoder().decode(Transcript.self, from: data)
    }
}
