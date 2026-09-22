import os
import Foundation

/// Production signal source: composes the process, microphone and window
/// observers and forwards their changes as `TeamsSignalEvent`s.
@MainActor
final class LiveTeamsSignalSource: TeamsSignalSource {

    private var continuation: AsyncStream<TeamsSignalEvent>.Continuation?
    private var processObserver: TeamsProcessObserver?
    private var microphoneObserver: TeamsMicrophoneObserver?
    private var windowObserver: TeamsWindowObserver?

    init() {}

    func start() -> AsyncStream<TeamsSignalEvent> {
        stop()
        let (stream, continuation) = AsyncStream<TeamsSignalEvent>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation

        let microphone = TeamsMicrophoneObserver { active in continuation.yield(.microphone(active)) }
        let window = TeamsWindowObserver { present in continuation.yield(.meetingWindow(present)) }
        let process = TeamsProcessObserver { [weak self] pids in
            self?.teamsProcessesChanged(pids)
        }
        microphoneObserver = microphone
        windowObserver = window
        processObserver = process

        let initialPIDs = process.start()
        microphone.start()
        teamsProcessesChanged(initialPIDs)
        return stream
    }

    func stop() {
        processObserver?.stop()
        microphoneObserver?.stop()
        windowObserver?.stop()
        processObserver = nil
        microphoneObserver = nil
        windowObserver = nil
        continuation?.finish()
        continuation = nil
    }

    private func teamsProcessesChanged(_ pids: Set<pid_t>) {
        Log.teams.info("Teams processes: \(pids.count) running")
        continuation?.yield(.teamsRunning(!pids.isEmpty))
        microphoneObserver?.setTeamsPIDs(pids)
        windowObserver?.setTeamsPIDs(pids)
    }
}
