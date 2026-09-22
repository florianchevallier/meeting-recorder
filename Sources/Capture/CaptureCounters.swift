import Foundation
import Synchronization

/// Lock-free counters written by the IO callback and read by the health loop.
final class CaptureCounters: Sendable {
    let ioCallbacks = Atomic<UInt64>(0)
    let droppedFrames = Atomic<UInt64>(0)
    /// `mach_absolute_time` of the last IO callback (0 = none yet).
    let lastIOHostTime = Atomic<UInt64>(0)
    /// Frames handed to the writer queue and not yet consumed (back-pressure).
    let pendingFrames = Atomic<Int>(0)
    private let systemPeakBits = Atomic<UInt32>(0)
    private let microphonePeakBits = Atomic<UInt32>(0)

    func recordPeaks(system: Float, microphone: Float) {
        raise(systemPeakBits, to: system)
        raise(microphonePeakBits, to: microphone)
    }

    /// Returns the counters and resets the peak meters.
    func snapshot() -> HealthSnapshot {
        HealthSnapshot(
            ioCallbacks: ioCallbacks.load(ordering: .relaxed),
            droppedFrames: droppedFrames.load(ordering: .relaxed),
            systemPeak: Float(bitPattern: systemPeakBits.exchange(0, ordering: .relaxed)),
            microphonePeak: Float(bitPattern: microphonePeakBits.exchange(0, ordering: .relaxed))
        )
    }

    private func raise(_ atomic: borrowing Atomic<UInt32>, to value: Float) {
        // Float bit patterns of non-negative values order like the floats themselves.
        let bits = max(value, 0).bitPattern
        var current = atomic.load(ordering: .relaxed)
        while bits > current {
            let (exchanged, original) = atomic.compareExchange(
                expected: current, desired: bits, ordering: .relaxed
            )
            if exchanged { return }
            current = original
        }
    }
}
