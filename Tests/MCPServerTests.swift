import Testing
import Foundation
@testable import MeetingRecorder

@Suite("MCPServer")
struct MCPServerTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func rpc(_ server: MCPServer, _ method: String, _ params: [String: Any] = [:]) throws -> [String: Any] {
        let request = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params] as [String: Any]
        let line = try #require(String(bytes: try JSONSerialization.data(withJSONObject: request), encoding: .utf8))
        let response = try #require(server.handle(line))
        return try #require(try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
    }

    private func text(_ response: [String: Any]) throws -> (String, Bool) {
        let result = try #require(response["result"] as? [String: Any])
        let content = try #require((result["content"] as? [[String: Any]])?.first)
        return (try #require(content["text"] as? String), result["isError"] as? Bool ?? false)
    }

    private func call(_ server: MCPServer, _ tool: String, _ arguments: [String: Any] = [:]) throws -> (String, Bool) {
        try text(rpc(server, "tools/call", ["name": tool, "arguments": arguments]))
    }

    @Test("Protocol: initialize, tools/list, unknown method, notification")
    func protocolBasics() throws {
        let server = MCPServer(directory: try directory())
        let initialize = try rpc(server, "initialize", ["protocolVersion": "2025-03-26"])
        #expect((initialize["result"] as? [String: Any])?["protocolVersion"] as? String == "2025-03-26")
        let tools = try #require(
            (try rpc(server, "tools/list")["result"] as? [String: Any])?["tools"] as? [[String: Any]])
        #expect(
            tools.compactMap { $0["name"] as? String } == ["list_recordings", "get_transcript", "get_live_transcript"])
        #expect(((try rpc(server, "nope")["error"]) as? [String: Any])?["code"] as? Int == -32601)
        #expect(server.handle(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        #expect(server.handle("not json")?.contains("-32700") == true)
    }

    @Test("list_recordings searches, get_transcript falls back to live and rejects bad ids")
    func recordings() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = dir.appendingPathComponent("meeting_2026-09-22_10-00-00_Point hebdo.m4a")
        let b = dir.appendingPathComponent("meeting_2026-09-23_10-00-00.m4a")
        for url in [a, b] { try Data().write(to: url) }
        try "Bonjour budget".write(to: RecordingFiles(audio: a).transcriptText, atomically: true, encoding: .utf8)
        try "Salut".write(to: RecordingFiles(audio: b).liveTranscript, atomically: true, encoding: .utf8)
        let server = MCPServer(directory: dir)

        let (list, _) = try call(server, "list_recordings", ["query": "budget"])
        #expect(list.contains(a.lastPathComponent) && !list.contains(b.lastPathComponent))
        #expect(try call(server, "get_transcript", ["id": a.lastPathComponent]).0 == "Bonjour budget")
        #expect(try call(server, "get_transcript", ["id": b.lastPathComponent]).0.hasSuffix("Salut"))
        for id in ["../x.m4a", "/etc/passwd", "meeting_x.partial.m4a", "meeting_missing.m4a"] {
            #expect(try call(server, "get_transcript", ["id": id]).1)
        }
    }

    @Test("get_live_transcript: fresh .partial only")
    func live() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let server = MCPServer(directory: dir)
        #expect(try call(server, "get_live_transcript").0 == "No recording in progress.")

        let audio = dir.appendingPathComponent("meeting_2026-09-23_10-00-00_Daily.m4a")
        let partial = dir.appendingPathComponent("meeting_2026-09-23_10-00-00_Daily.partial.m4a")
        try Data().write(to: partial)
        try "**[00:01] Me** — hello".write(
            to: RecordingFiles(audio: audio).liveTranscript, atomically: true, encoding: .utf8)
        let (fresh, _) = try call(server, "get_live_transcript")
        #expect(fresh.contains("Daily") && fresh.contains("hello"))

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -600)], ofItemAtPath: partial.path)
        #expect(try call(server, "get_live_transcript").0 == "No recording in progress.")
    }
}

@Suite("MCPInstall")
struct MCPInstallTests {
    @Test("Claude Code command quotes paths the shell would split")
    func command() {
        #expect(
            MCPInstall.claudeCodeCommand(executable: "/Applications/Meety.app/Contents/MacOS/MeetingRecorder")
                == "claude mcp add meety -- /Applications/Meety.app/Contents/MacOS/MeetingRecorder mcp")
        #expect(
            MCPInstall.claudeCodeCommand(executable: "/Users/a b/it's/MeetingRecorder")
                == "claude mcp add meety -- '/Users/a b/it'\\''s/MeetingRecorder' mcp")
    }

    @Test("Client config is valid JSON naming the executable and the mcp argument")
    func json() throws {
        let json = MCPInstall.clientConfigJSON(executable: "/A B/MeetingRecorder")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let server = try #require((root["mcpServers"] as? [String: Any])?["meety"] as? [String: Any])
        #expect(server["command"] as? String == "/A B/MeetingRecorder")
        #expect(server["args"] as? [String] == ["mcp"])
    }
}
