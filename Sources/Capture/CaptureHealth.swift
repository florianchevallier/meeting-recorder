import Foundation

/// Counters sampled from the IO path. Produced by `CaptureCounters.snapshot()`.
struct HealthSnapshot: Sendable, Equatable {
    var ioCallbacks: UInt64 = 0
    var ioFrames: UInt64 = 0
    var droppedFrames: UInt64 = 0
    /// Linear peak (0…1) seen on the system tap since the previous snapshot.
    var systemPeak: Float = 0
    var microphonePeak: Float = 0
}

enum HealthVerdict: Sendable, Equatable {
    case healthy
    /// No IO callback for this long.
    case stalled(seconds: TimeInterval)
    /// The device delivers frames at a rate other than the one the formats were built
    /// for (e.g. a Bluetooth headset switching to its 16 kHz hands-free profile once the
    /// mic opens): the audio would play sped up or slowed down until the tap is rebuilt.
    case sampleRateMismatch(effective: Double, expected: Double)
    /// Frames dropped since the previous evaluation (writer back-pressure).
    case dropping(frames: UInt64)
    /// The system tap has been below the silence threshold for this long.
    case systemSilent(seconds: TimeInterval)
}

/// Pure, stateful evaluator: feed it snapshots at a fixed cadence.
struct HealthEvaluator: Sendable {
    let stallTimeout: TimeInterval
    let silenceTimeout: TimeInterval
    /// Linear amplitude under which the tap counts as silent (-80 dBFS).
    let silenceThreshold: Float
    /// Relative deviation of the effective rate that counts as a mismatch.
    let rateTolerance: Double
    /// Consecutive mismatching intervals before reporting (a short IO hiccup is not a rate change).
    let rateMismatchIntervals: Int

    /// Rate the stream formats were resolved at; nil = not checked.
    private var expectedSampleRate: Double?
    private var previous: HealthSnapshot?
    private var stalledFor: TimeInterval = 0
    private var silentFor: TimeInterval = 0
    private var mismatchedIntervals = 0

    init(
        stallTimeout: TimeInterval = Constants.Recording.healthStallTimeout,
        silenceTimeout: TimeInterval = Constants.Recording.systemSilenceTimeout,
        silenceThreshold: Float = 0.0001,
        rateTolerance: Double = 0.1,
        rateMismatchIntervals: Int = 2
    ) {
        self.stallTimeout = stallTimeout
        self.silenceTimeout = silenceTimeout
        self.silenceThreshold = silenceThreshold
        self.rateTolerance = rateTolerance
        self.rateMismatchIntervals = rateMismatchIntervals
    }

    /// Call after the tap (re)started so the first quiet interval is not a stall.
    mutating func reset(expectedSampleRate: Double? = nil) {
        self.expectedSampleRate = expectedSampleRate
        previous = nil
        stalledFor = 0
        silentFor = 0
        mismatchedIntervals = 0
    }

    mutating func evaluate(_ current: HealthSnapshot, elapsed: TimeInterval) -> HealthVerdict {
        defer { previous = current }
        guard let previous else { return .healthy }

        if current.ioCallbacks == previous.ioCallbacks {
            stalledFor += elapsed
        } else {
            stalledFor = 0
        }
        if current.systemPeak < silenceThreshold {
            silentFor += elapsed
        } else {
            silentFor = 0
        }

        if stalledFor >= stallTimeout {
            return .stalled(seconds: stalledFor)
        }
        if let expected = expectedSampleRate, elapsed > 0, current.ioFrames > previous.ioFrames {
            let effective = Double(current.ioFrames - previous.ioFrames) / elapsed
            if abs(effective / expected - 1) > rateTolerance {
                mismatchedIntervals += 1
                if mismatchedIntervals >= rateMismatchIntervals {
                    return .sampleRateMismatch(effective: effective, expected: expected)
                }
            } else {
                mismatchedIntervals = 0
            }
        }
        let dropped = current.droppedFrames &- previous.droppedFrames
        if dropped > 0 {
            return .dropping(frames: dropped)
        }
        if silentFor >= silenceTimeout {
            return .systemSilent(seconds: silentFor)
        }
        return .healthy
    }
}
