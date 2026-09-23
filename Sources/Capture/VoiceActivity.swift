import Foundation

/// Microphone and system audio levels over the recording, one RMS value per
/// window, aligned with the file timeline. Written next to the recording as
/// `<name>.activity.json`; used to tell which diarized speaker is the local user.
struct VoiceActivity: Codable, Sendable, Equatable {
    static let currentVersion = 1

    let version: Int
    let windowSeconds: Double
    /// dBFS per window, clamped to −127…0.
    let microphone: [Int8]
    let system: [Int8]

    init(windowSeconds: Double, microphone: [Int8], system: [Int8]) {
        self.version = Self.currentVersion
        self.windowSeconds = windowSeconds
        self.microphone = microphone
        self.system = system
    }

    /// True when the local user is likely speaking at `time` (seconds from the start).
    func isMicrophoneDominant(at time: Double, thresholds: SpeakerLabeler.Thresholds) -> Bool {
        guard time >= 0, windowSeconds > 0 else { return false }
        let index = Int(time / windowSeconds)
        guard index < microphone.count, index < system.count else { return false }
        let mic = Int(microphone[index])
        return mic >= thresholds.micFloorDB && mic - Int(system[index]) >= thresholds.dominanceDB
    }

    // MARK: Files

    func write(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> VoiceActivity {
        try JSONDecoder().decode(VoiceActivity.self, from: Data(contentsOf: url))
    }
}

/// Accumulates the two mono streams, sample-aligned, into `VoiceActivity`
/// windows. A value type owned by `AudioFileWriter` (queue-confined there).
struct VoiceActivityRecorder {
    static let windowSeconds = 0.25

    private let windowFrames: Int
    private var microphoneSquares: Double = 0
    private var systemSquares: Double = 0
    private var framesInWindow = 0
    private var microphone: [Int8] = []
    private var system: [Int8] = []

    init(sampleRate: Double = CaptureFormat.sampleRate) {
        windowFrames = max(1, Int(sampleRate * Self.windowSeconds))
    }

    /// `count` frames of the mix; a stream shorter than `count` is padded with silence.
    mutating func add(
        system systemSamples: ArraySlice<Float>, microphone microphoneSamples: ArraySlice<Float>, count: Int
    ) {
        var systemIndex = systemSamples.startIndex
        var microphoneIndex = microphoneSamples.startIndex
        for _ in 0..<count {
            if systemIndex < systemSamples.endIndex {
                let s = Double(systemSamples[systemIndex])
                systemSquares += s * s
                systemIndex += 1
            }
            if microphoneIndex < microphoneSamples.endIndex {
                let m = Double(microphoneSamples[microphoneIndex])
                microphoneSquares += m * m
                microphoneIndex += 1
            }
            framesInWindow += 1
            if framesInWindow == windowFrames { closeWindow() }
        }
    }

    mutating func addSilence(frames: Int) {
        add(system: [], microphone: [], count: frames)
    }

    /// Everything recorded so far, the partial last window included.
    func result() -> VoiceActivity {
        var copy = self
        if copy.framesInWindow > 0 { copy.closeWindow() }
        return VoiceActivity(windowSeconds: Self.windowSeconds, microphone: copy.microphone, system: copy.system)
    }

    private mutating func closeWindow() {
        microphone.append(Self.decibels(meanSquare: microphoneSquares / Double(framesInWindow)))
        system.append(Self.decibels(meanSquare: systemSquares / Double(framesInWindow)))
        microphoneSquares = 0
        systemSquares = 0
        framesInWindow = 0
    }

    static func decibels(meanSquare: Double) -> Int8 {
        guard meanSquare > 0 else { return -127 }
        return Int8(min(0, max(-127, (10 * log10(meanSquare)).rounded())))
    }
}
