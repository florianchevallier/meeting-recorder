import Testing
import Foundation
import Synchronization
@testable import MeetingRecorder

@Suite("Server wake-up")
struct ServerWakeUpTests {

    private func client(_ server: StubServer) -> WhisperAPIClient {
        WhisperAPIClient(baseURL: server.baseURL, apiKey: "key", session: server.session())
    }

    @Test("503 while waking up, then 200: waits one probe interval and reports asleep once")
    func wakesUp() async throws {
        let probes = Counter()
        let server = StubServer { _ in probes.next() < 3 ? (503, "") : (200, "{}") }
        let clock = InstantClock()
        var asleepCalls = 0

        try await client(server).waitUntilAwake(
            clock: clock, interval: .seconds(10), timeout: .seconds(480), onAsleep: { asleepCalls += 1 })

        #expect(server.count("GET /api/status") == 4)
        #expect(asleepCalls == 1)
        #expect(clock.elapsed == .seconds(30))
    }

    @Test("Awake at once: no sleep, no asleep notice")
    func alreadyAwake() async throws {
        let server = StubServer { _ in (200, "{}") }
        let clock = InstantClock()
        var asleepCalls = 0
        try await client(server).waitUntilAwake(clock: clock, onAsleep: { asleepCalls += 1 })
        #expect(asleepCalls == 0)
        #expect(clock.elapsed == .zero)
    }

    @Test("Still 503 after the timeout: serverDidNotWake")
    func timeout() async {
        let server = StubServer { _ in (504, "") }
        let clock = InstantClock()
        await #expect {
            try await client(server).waitUntilAwake(clock: clock, interval: .seconds(10), timeout: .seconds(480))
        } throws: { error in
            if case APIError.serverDidNotWake = error { return true }
            return false
        }
        #expect(clock.elapsed < .seconds(480))
        #expect(clock.elapsed >= .seconds(460))
    }

    @Test("A server without /status (404) does not block the upload")
    func noStatusRoute() async throws {
        let server = StubServer { _ in (404, "") }
        try await client(server).waitUntilAwake(clock: InstantClock())
        #expect(server.count("GET /api/status") == 1)
    }
}

/// Thread-safe call counter for stub handlers.
final class Counter: Sendable {
    private let value = Mutex(0)
    /// Returns the current value, then increments it.
    func next() -> Int {
        value.withLock {
            defer { $0 += 1 }; return $0
        }
    }
}
