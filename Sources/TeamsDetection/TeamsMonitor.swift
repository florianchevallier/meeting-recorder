import os
import Foundation

/// Merges the Teams signals into one debounced meeting state and publishes the
/// transitions over `meetingChanges`. Zero periodic work: everything is driven
/// by the source's events. Main-actor bound because the live observers deliver
/// on the main run loop and the only consumer is the main-actor coordinator.
@MainActor
final class TeamsMonitor {

    // MARK: - Events

    /// Emits `true` when a meeting starts, `false` when it ends (changes only).
    nonisolated let meetingChanges: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    // MARK: - State

    private let source: any TeamsSignalSource
    private let clock: any Clock<Duration>
    private let debounce: Duration

    private var teamsRunning = false
    private var hasMeetingWindow = false
    private var microphoneActive = false
    private(set) var isMeetingActive = false

    private var eventsTask: Task<Void, Never>?
    private var pending: (target: Bool, task: Task<Void, Never>)?

    // MARK: - Init

    init(
        source: any TeamsSignalSource = LiveTeamsSignalSource(),
        clock: any Clock<Duration> = ContinuousClock(),
        debounce: Duration = .seconds(Constants.TeamsDetection.debounce)
    ) {
        self.source = source
        self.clock = clock
        self.debounce = debounce
        (meetingChanges, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    // MARK: - Lifecycle

    func start() {
        guard eventsTask == nil else { return }
        Log.teams.info("Starting Teams meeting detection (event-driven)")
        let stream = source.start()
        eventsTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                self.apply(event)
            }
        }
    }

    func stop() {
        Log.teams.info("Stopping Teams meeting detection")
        eventsTask?.cancel()
        eventsTask = nil
        pending?.task.cancel()
        pending = nil
        source.stop()
        continuation.finish()
    }

    // MARK: - Merge + debounce

    private func apply(_ event: TeamsSignalEvent) {
        switch event {
        case .teamsRunning(let running):
            teamsRunning = running
            if !running {
                hasMeetingWindow = false
                microphoneActive = false
            }
        case .meetingWindow(let value):
            hasMeetingWindow = value
        case .microphone(let value):
            microphoneActive = value
        }

        let decision = TeamsMeetingDecider.decide(
            for: .init(hasMeetingWindow: hasMeetingWindow, microphoneActive: microphoneActive)
        )
        let target = teamsRunning && decision.isActive
        Log.teams.debug(
            "Signals — running: \(self.teamsRunning) window: \(self.hasMeetingWindow) mic: \(self.microphoneActive) → \(String(describing: decision), privacy: .public)"
        )
        schedule(target)
    }

    /// Emits `target` only if it still holds after the debounce window.
    private func schedule(_ target: Bool) {
        if target == isMeetingActive {
            pending?.task.cancel()
            pending = nil
            return
        }
        if let pending, pending.target == target { return }
        pending?.task.cancel()

        let clock = self.clock
        let debounce = self.debounce
        pending = (
            target,
            Task { [weak self] in
                try? await clock.sleep(for: debounce)
                guard !Task.isCancelled, let self else { return }
                self.pending = nil
                self.isMeetingActive = target
                Log.teams.info("Meeting \(target ? "started" : "ended", privacy: .public)")
                self.continuation.yield(target)
            }
        )
    }
}
