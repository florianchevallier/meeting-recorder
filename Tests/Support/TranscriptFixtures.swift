import Foundation
@testable import MeetingRecorder

/// Builders for transcript tests.
enum TranscriptFixtures {
    /// One segment whose words are spread evenly over `start..<end`.
    static func segment(_ speaker: String?, _ start: Double, _ end: Double, _ text: String) -> Transcript.Segment {
        let tokens = text.split(separator: " ").map(String.init)
        let step = (end - start) / Double(max(tokens.count, 1))
        let words = tokens.enumerated().map { index, token in
            Transcript.Word(
                word: token, start: start + Double(index) * step, end: start + Double(index + 1) * step,
                speaker: speaker)
        }
        return Transcript.Segment(start: start, end: end, text: " " + text, speaker: speaker, words: words)
    }

    /// Activity where the microphone dominates during `mine` and the system audio elsewhere.
    static func activity(seconds: Double, mine: [Range<Double>]) -> VoiceActivity {
        let window = VoiceActivityRecorder.windowSeconds
        let count = Int(seconds / window)
        var mic: [Int8] = []
        var system: [Int8] = []
        for index in 0..<count {
            let time = (Double(index) + 0.5) * window
            let isMine = mine.contains { $0.contains(time) }
            mic.append(isMine ? -20 : -60)
            system.append(isMine ? -70 : -18)
        }
        return VoiceActivity(windowSeconds: window, microphone: mic, system: system)
    }
}
