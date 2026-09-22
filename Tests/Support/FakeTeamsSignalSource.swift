import Foundation
@testable import MeetingRecorder

/// Scriptable `TeamsSignalSource` for `TeamsMonitor` tests.
@MainActor
final class FakeTeamsSignalSource: TeamsSignalSource {
    private var continuation: AsyncStream<TeamsSignalEvent>.Continuation?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() -> AsyncStream<TeamsSignalEvent> {
        startCount += 1
        let (stream, continuation) = AsyncStream<TeamsSignalEvent>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation
        return stream
    }

    func stop() {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func send(_ event: TeamsSignalEvent) {
        continuation?.yield(event)
    }
}
