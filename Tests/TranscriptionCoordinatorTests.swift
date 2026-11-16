import Testing
import Foundation
@testable import MeetingRecorder

/// End-to-end runs of the coordinator against a stub server and an instant clock.
@Suite("TranscriptionCoordinator")
@MainActor
struct TranscriptionCoordinatorTests {

    nonisolated static let accepted = """
        {"success":true,"message":"ok","jobId":"j1",
         "links":{"status":"s","logs":"l","logsStream":"ls","result":"r"}}
        """
    nonisolated static func job(_ status: String) -> String {
        """
        {"success":true,"job":{"id":"j1","status":"\(status)","createdAt":"t","updatedAt":"t"}}
        """
    }

    /// Runs one transcription to its end and returns the coordinator and the recording.
    private func run(_ server: StubServer) async throws -> (TranscriptionCoordinator, RecordingFiles) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audio = directory.appendingPathComponent("meeting_2026-11-16_10-00-00.m4a")
        try Data("audio".utf8).write(to: audio)

        let settings = SettingsStore(defaults: ScratchDefaults.make())
        settings.apiBaseURL = server.baseURL
        let coordinator = TranscriptionCoordinator(
            settings: settings, apiKey: { "key" }, session: server.session(), clock: InstantClock())
        coordinator.enqueue(audio)
        for _ in 0..<500 where coordinator.isPending(audio) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!coordinator.isPending(audio))
        return (coordinator, RecordingFiles(audio: audio))
    }

    nonisolated private static func route(_ route: String, process: () -> (Int, String), job: () -> (Int, String)) -> (
        Int, String
    ) {
        switch route {
        case "GET /api/status": return (200, "{}")
        case "POST /api/process": return process()
        case "GET /api/jobs/j1": return job()
        case "GET /api/jobs/j1/result": return (200, TranscriptTests.serverJSON)
        default: return (200, "{}")  // DELETE
        }
    }

    @Test("503 on the upload (server fell asleep): probes again, sends again, keeps going")
    func uploadRefusedThenResent() async throws {
        let uploads = Counter()
        let server = StubServer { route in
            Self.route(
                route, process: { uploads.next() == 0 ? (503, "") : (202, Self.accepted) },
                job: { (200, Self.job("completed")) })
        }
        let (coordinator, files) = try await run(server)

        #expect(server.count("POST /api/process") == 2)
        #expect(server.count("GET /api/status") == 2)
        #expect(coordinator.lastFailed == nil)
        #expect(FileManager.default.fileExists(atPath: files.transcriptText.path))
        #expect(!FileManager.default.fileExists(atPath: files.pendingJob.path))
    }

    @Test("503 while polling counts as a transient failure, the job still completes")
    func pollingSurvives503() async throws {
        let polls = Counter()
        let server = StubServer { route in
            Self.route(
                route, process: { (202, Self.accepted) },
                job: { polls.next() < 2 ? (503, "") : (200, Self.job("completed")) })
        }
        let (coordinator, files) = try await run(server)

        #expect(server.count("GET /api/jobs/j1") == 3)
        #expect(server.count("POST /api/process") == 1)
        #expect(coordinator.lastFailed == nil)
        #expect(FileManager.default.fileExists(atPath: files.transcriptText.path))
    }

    @Test("Server that never wakes up: fails with a clear message, nothing uploaded")
    func neverWakes() async throws {
        let server = StubServer { route in route == "GET /api/status" ? (503, "") : (500, "") }
        let (coordinator, _) = try await run(server)

        #expect(server.count("POST /api/process") == 0)
        #expect(coordinator.lastFailed != nil)
        #expect(coordinator.state.error == L10n.apiErrorServerDidNotWake)
    }

    @Test("Early wake-up pings /status once per recording, the stop doesn't ping again")
    func earlyWakeUp() async throws {
        let server = StubServer { _ in (200, "{}") }
        let settings = SettingsStore(defaults: ScratchDefaults.make())
        settings.apiBaseURL = server.baseURL
        settings.transcriptionEnabled = true
        let coordinator = TranscriptionCoordinator(
            settings: settings, apiKey: { nil }, session: server.session(), clock: InstantClock())

        coordinator.scheduleServerWakeUp(meetingEnd: Date().addingTimeInterval(60))  // < 5 min: at once
        for _ in 0..<200 where server.count("GET /api/status") == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        coordinator.wakeServerOnStop()
        try await Task.sleep(for: .milliseconds(50))
        #expect(server.count("GET /api/status") == 1)

        coordinator.wakeServerOnStop()  // next recording, no event: pings at stop
        for _ in 0..<200 where server.count("GET /api/status") == 1 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(server.count("GET /api/status") == 2)
    }

    @Test("Waking the server shows its own progress message")
    func wakingMessage() {
        var state = TranscriptionState()
        TranscriptionStateReducer.reduce(&state, .prepare)
        TranscriptionStateReducer.reduce(&state, .progressMessage(L10n.transcriptionProgressWaking))
        #expect(state.progress == L10n.transcriptionProgressWaking)
        #expect(state.isTranscribing)
    }
}
