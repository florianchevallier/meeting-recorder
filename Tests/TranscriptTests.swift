import Testing
import Foundation
@testable import MeetingRecorder

@Suite("Transcript")
struct TranscriptTests {
    /// Shape returned by the WhisperX server with `outputFormat=json` (trimmed).
    static let serverJSON = """
        {"segments":[
          {"start":1.572,"end":15.102,"text":" leur archi, leur urbaniste.","words":[
            {"word":"leur","start":1.572,"end":1.652,"score":0.44,"speaker":"SPEAKER_01"},
            {"word":"23.","speaker":"SPEAKER_01"}],"speaker":"SPEAKER_01"},
          {"start":15.5,"end":17.0,"text":" Oui.","words":[]},
          {"start":17.2,"end":20.0,"text":" D'accord.","speaker":"SPEAKER_00"}],
         "word_segments":[{"word":"leur","start":1.572,"end":1.652,"score":0.44,"speaker":"SPEAKER_01"}]}
        """

    @Test("Decodes the server JSON, unaligned words and unlabeled segments included")
    func decode() throws {
        let transcript = try Transcript.decode(Data(Self.serverJSON.utf8))
        #expect(transcript.segments.count == 3)
        #expect(transcript.segments[0].words?[1].start == nil)
        #expect(transcript.segments[1].speaker == nil)
        #expect(transcript.segments[2].words == nil)
    }

    @Test("Speakers are listed in order of first appearance")
    func speakers() throws {
        let transcript = try Transcript.decode(Data(Self.serverJSON.utf8))
        #expect(transcript.speakers == ["SPEAKER_01", "SPEAKER_00"])
    }

    @Test("A plain-text result is rejected")
    func rejectsText() {
        #expect(throws: (any Error).self) { try Transcript.decode(Data("[SPEAKER_00]: Bonjour".utf8)) }
    }
}
