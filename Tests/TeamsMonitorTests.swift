import Testing
import Foundation
@testable import MeetingRecorder

/// Collects the monitor's emissions on the main actor.
@MainActor
private final class Collector {
    private(set) var values: [Bool] = []
    private(set) var finished = false
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Bool>) {
        task = Task {
            for await value in stream { self.values.append(value) }
            self.finished = true
        }
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<1_000 where values.count < count { await Task.yield() }
    }

    func waitForFinish() async {
        for _ in 0..<1_000 where !finished { await Task.yield() }
    }
}

@MainActor
@Suite("TeamsMonitor (event-driven, debounced)")
struct TeamsMonitorTests {

    private func makeMonitor() -> (TeamsMonitor, FakeTeamsSignalSource, ManualClock, Collector) {
        let source = FakeTeamsSignalSource()
        let clock = ManualClock()
        let monitor = TeamsMonitor(source: source, clock: clock, debounce: .seconds(3))
        let collector = Collector(monitor.meetingChanges)
        monitor.start()
        return (monitor, source, clock, collector)
    }

    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }

    private func sendMeetingSignals(_ source: FakeTeamsSignalSource) {
        source.send(.teamsRunning(true))
        source.send(.meetingWindow(true))
        source.send(.microphone(true))
    }

    @Test("Window + mic emits true only after the debounce")
    func startsAfterDebounce() async {
        let (monitor, source, clock, collector) = makeMonitor()
        sendMeetingSignals(source)
        await clock.waitForSleepers(1)
        #expect(!monitor.isMeetingActive)

        clock.advance(by: .seconds(2))
        await settle()
        #expect(!monitor.isMeetingActive)
        #expect(collector.values.isEmpty)

        clock.advance(by: .seconds(1))
        await collector.waitForCount(1)
        #expect(collector.values == [true])
        #expect(monitor.isMeetingActive)
    }

    @Test("A flicker shorter than the debounce emits nothing")
    func flickerIsIgnored() async {
        let (monitor, source, clock, collector) = makeMonitor()
        sendMeetingSignals(source)
        await clock.waitForSleepers(1)
        source.send(.microphone(false))  // cancels the pending start
        await settle()
        clock.advance(by: .seconds(10))
        await settle()
        #expect(!monitor.isMeetingActive)
        #expect(collector.values.isEmpty)
        #expect(clock.sleeperCount == 0)
    }

    @Test("Meeting ends when the microphone stops, after the debounce")
    func endsAfterDebounce() async {
        let (monitor, source, clock, collector) = makeMonitor()
        sendMeetingSignals(source)
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(3))
        await collector.waitForCount(1)

        source.send(.microphone(false))
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(3))
        await collector.waitForCount(2)
        #expect(collector.values == [true, false])
        #expect(!monitor.isMeetingActive)
    }

    @Test("Teams quitting resets window and mic so a relaunch alone does not re-arm")
    func teamsQuitResets() async {
        let (monitor, source, clock, collector) = makeMonitor()
        sendMeetingSignals(source)
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(3))
        await collector.waitForCount(1)

        source.send(.teamsRunning(false))
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(3))
        await collector.waitForCount(2)
        #expect(collector.values == [true, false])

        source.send(.teamsRunning(true))
        await settle()
        #expect(clock.sleeperCount == 0)
        #expect(!monitor.isMeetingActive)
    }

    @Test("stop() finishes the stream and stops the source")
    func stopFinishes() async {
        let (monitor, source, _, collector) = makeMonitor()
        monitor.stop()
        #expect(source.stopCount == 1)
        await collector.waitForFinish()
        #expect(collector.finished)
        #expect(collector.values.isEmpty)
    }

    @Test("Duplicate events do not restart the debounce")
    func duplicatesDoNotRestart() async {
        let (monitor, source, clock, collector) = makeMonitor()
        defer { withExtendedLifetime(monitor) {} }
        sendMeetingSignals(source)
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(2))
        source.send(.microphone(true))  // same target: the pending countdown continues
        await settle()
        #expect(clock.sleeperCount == 1)
        clock.advance(by: .seconds(1))
        await collector.waitForCount(1)
        #expect(collector.values == [true])
    }
}
