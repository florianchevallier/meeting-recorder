import Testing
import Foundation
@testable import MeetingRecorder

@Suite("HealthEvaluator")
struct HealthEvaluatorTests {
    func snapshot(callbacks: UInt64, dropped: UInt64 = 0, peak: Float = 0.1) -> HealthSnapshot {
        HealthSnapshot(ioCallbacks: callbacks, droppedFrames: dropped, systemPeak: peak, microphonePeak: 0.1)
    }

    @Test("First evaluation is always healthy (no baseline yet)")
    func firstIsHealthy() {
        var evaluator = HealthEvaluator(stallTimeout: 3, silenceTimeout: 30)
        #expect(evaluator.evaluate(snapshot(callbacks: 0), elapsed: 2) == .healthy)
    }

    @Test("Stall is reported once callbacks stop for the timeout")
    func stall() {
        var evaluator = HealthEvaluator(stallTimeout: 3, silenceTimeout: 30)
        _ = evaluator.evaluate(snapshot(callbacks: 10), elapsed: 2)
        #expect(evaluator.evaluate(snapshot(callbacks: 10), elapsed: 2) == .healthy)
        #expect(evaluator.evaluate(snapshot(callbacks: 10), elapsed: 2) == .stalled(seconds: 4))
        // Callbacks resume → healthy again
        #expect(evaluator.evaluate(snapshot(callbacks: 11), elapsed: 2) == .healthy)
    }

    @Test("Dropped frames since the previous snapshot are reported")
    func dropping() {
        var evaluator = HealthEvaluator(stallTimeout: 3, silenceTimeout: 30)
        _ = evaluator.evaluate(snapshot(callbacks: 1, dropped: 100), elapsed: 2)
        #expect(evaluator.evaluate(snapshot(callbacks: 2, dropped: 150), elapsed: 2) == .dropping(frames: 50))
        #expect(evaluator.evaluate(snapshot(callbacks: 3, dropped: 150), elapsed: 2) == .healthy)
    }

    @Test("System silence is reported after the silence timeout and cleared by signal")
    func silence() {
        var evaluator = HealthEvaluator(stallTimeout: 3, silenceTimeout: 4)
        _ = evaluator.evaluate(snapshot(callbacks: 1, peak: 0), elapsed: 2)
        #expect(evaluator.evaluate(snapshot(callbacks: 2, peak: 0), elapsed: 2) == .healthy)
        #expect(evaluator.evaluate(snapshot(callbacks: 3, peak: 0), elapsed: 2) == .systemSilent(seconds: 4))
        #expect(evaluator.evaluate(snapshot(callbacks: 4, peak: 0.2), elapsed: 2) == .healthy)
    }

    @Test("Stall wins over silence; reset clears accumulated state")
    func priorityAndReset() {
        var evaluator = HealthEvaluator(stallTimeout: 2, silenceTimeout: 2)
        _ = evaluator.evaluate(snapshot(callbacks: 1, peak: 0), elapsed: 2)
        #expect(evaluator.evaluate(snapshot(callbacks: 1, peak: 0), elapsed: 2) == .stalled(seconds: 2))
        evaluator.reset()
        #expect(evaluator.evaluate(snapshot(callbacks: 1, peak: 0), elapsed: 2) == .healthy)
    }
}
