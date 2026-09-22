import Testing
import Foundation
@testable import MeetingRecorder

@Suite("VoiceActivityRecorder")
struct VoiceActivityRecorderTests {

    @Test("One window per 250 ms, RMS in dBFS, partial last window kept")
    func windows() {
        var recorder = VoiceActivityRecorder(sampleRate: 1_000)  // 250 frames per window
        let loud = ArraySlice([Float](repeating: 0.5, count: 600))
        recorder.add(system: loud, microphone: [], count: 600)

        let activity = recorder.result()
        #expect(activity.system == [-6, -6, -6])  // 20·log10(0.5) ≈ −6
        #expect(activity.microphone == [-127, -127, -127])
        #expect(activity.windowSeconds == 0.25)
    }

    @Test("Silence advances the timeline")
    func silence() {
        var recorder = VoiceActivityRecorder(sampleRate: 1_000)
        recorder.add(system: [], microphone: ArraySlice([Float](repeating: 0.1, count: 250)), count: 250)
        recorder.addSilence(frames: 500)
        #expect(recorder.result().microphone == [-20, -127, -127])
    }

    @Test("Mic-dominant detection uses the window under the timestamp")
    func dominance() {
        let activity = VoiceActivity(windowSeconds: 0.25, microphone: [-20, -20, -50], system: [-60, -25, -60])
        let thresholds = SpeakerLabeler.Thresholds()
        #expect(activity.isMicrophoneDominant(at: 0.1, thresholds: thresholds))
        #expect(!activity.isMicrophoneDominant(at: 0.3, thresholds: thresholds))  // only 5 dB louder
        #expect(!activity.isMicrophoneDominant(at: 0.6, thresholds: thresholds))  // under the floor
        #expect(!activity.isMicrophoneDominant(at: 9, thresholds: thresholds))  // past the end
    }

    @Test("Round-trips through its sidecar file")
    func codable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("activity-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let activity = VoiceActivity(windowSeconds: 0.25, microphone: [-20, -127], system: [0, -40])
        try activity.write(to: url)
        #expect(try VoiceActivity.read(from: url) == activity)
    }
}
