import Foundation
import Synchronization

/// Deterministic `Clock` for tests: time only moves when `advance(by:)` is called.
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol, Sendable {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [Sleeper] = []
    }

    private let state = Mutex(State())

    var now: Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .zero }

    /// Number of tasks currently suspended in `sleep`.
    var sleeperCount: Int { state.withLock { $0.sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let resumeNow = state.withLock { state -> Bool in
                if deadline <= state.now { return true }
                state.sleepers.append(Sleeper(deadline: deadline, continuation: continuation))
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func advance(by duration: Duration) {
        let due = state.withLock { state -> [Sleeper] in
            state.now = state.now.advanced(by: duration)
            let (due, rest) = state.sleepers.reduce(into: ([Sleeper](), [Sleeper]())) { acc, sleeper in
                if sleeper.deadline <= state.now { acc.0.append(sleeper) } else { acc.1.append(sleeper) }
            }
            state.sleepers = rest
            return due
        }
        due.forEach { $0.continuation.resume() }
    }

    /// Yields until at least `count` tasks are suspended in `sleep` (bounded).
    func waitForSleepers(_ count: Int) async {
        for _ in 0..<1_000 where sleeperCount < count {
            await Task.yield()
        }
    }
}
