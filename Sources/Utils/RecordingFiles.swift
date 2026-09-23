import Foundation

/// Every file that lives next to a recording, derived from the audio URL:
/// `meeting_…​.m4a` → `meeting_…​.txt`, `meeting_…​.meeting.json`, …
struct RecordingFiles: Sendable, Equatable {
    let audio: URL

    /// Rendered transcript (what the popover opens).
    var transcriptText: URL { sibling("txt") }
    /// Raw WhisperX JSON result, kept to re-render without a new upload.
    var transcriptJSON: URL { sibling("transcript.json") }
    /// Calendar event the recording belongs to (`MeetingMetadata`).
    var meetingMetadata: URL { sibling("meeting.json") }
    /// Microphone vs system levels over time (`VoiceActivity`).
    var voiceActivity: URL { sibling("activity.json") }
    /// Speaker names chosen by the user (`SPEAKER_00` → "Alice").
    var speakerNames: URL { sibling("speakers.json") }
    /// Server job in flight, so a relaunch resumes polling instead of re-uploading.
    var pendingJob: URL { sibling("transcription-job.json") }
    /// On-device transcript written while recording (`LiveTranscriptionCoordinator`).
    var liveTranscript: URL { sibling("live.md") }

    private func sibling(_ pathExtension: String) -> URL {
        audio.deletingPathExtension().appendingPathExtension(pathExtension)
    }
}
