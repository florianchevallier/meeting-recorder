import Testing
import Foundation
@testable import MeetingRecorder

@Suite("RecordingFiles")
struct RecordingFilesTests {
    @Test("Sidecars sit next to the recording, named after it")
    func sidecars() {
        let files = RecordingFiles(audio: URL(fileURLWithPath: "/Docs/meeting_2026-09-22_10-00-00_Point.m4a"))
        #expect(files.transcriptText.path == "/Docs/meeting_2026-09-22_10-00-00_Point.txt")
        #expect(files.transcriptJSON.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.transcript.json")
        #expect(files.meetingMetadata.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.meeting.json")
        #expect(files.voiceActivity.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.activity.json")
        #expect(files.speakerNames.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.speakers.json")
        #expect(files.pendingJob.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.transcription-job.json")
        #expect(files.liveTranscript.lastPathComponent == "meeting_2026-09-22_10-00-00_Point.live.md")
        #expect(MeetingMetadata.url(forRecording: files.audio) == files.meetingMetadata)
    }
}
