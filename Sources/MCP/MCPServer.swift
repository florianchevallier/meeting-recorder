import Foundation

/// Minimal MCP server over stdio (one JSON-RPC message per line) that exposes the recordings
/// folder to an LLM: past transcripts and the live transcript of the recording in progress.
/// Reads files only, so it works while the app is closed. Nothing but JSON-RPC may reach stdout.
/// ponytail: the live text is the `.live.md` finals (10–30 s behind); volatile text would need
/// the app process (HTTP) — upgrade then.
struct MCPServer: Sendable {
    let directory: URL?
    /// A `.partial` file untouched for longer than this is a crashed recording, not a live one
    /// (the writer fragments every 10 s).
    static let liveFreshness: TimeInterval = 60

    init(directory: URL? = try? FileSystemUtilities.recordingsDirectory()) {
        self.directory = directory
    }

    func run() {
        while let line = readLine() {
            guard let response = handle(line) else { continue }
            FileHandle.standardOutput.write(Data((response + "\n").utf8))
        }
    }

    // MARK: JSON-RPC

    /// Response line for one request line; `nil` for notifications.
    func handle(_ line: String) -> String? {
        guard let data = line.data(using: .utf8),
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return Self.encode(["jsonrpc": "2.0", "id": NSNull(), "error": Self.error(-32700, "Parse error")]) }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        var response: [String: Any] = ["jsonrpc": "2.0", "id": id]
        switch message["method"] as? String {
        case "initialize":
            response["result"] = [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": [
                    "name": "meety",
                    "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
                ],
            ]
        case "ping":
            response["result"] = [String: Any]()
        case "tools/list":
            response["result"] = ["tools": Self.tools]
        case "tools/call":
            guard let name = params["name"] as? String, Self.tools.contains(where: { $0["name"] as? String == name })
            else {
                response["error"] = Self.error(-32602, "Unknown tool")
                break
            }
            let (text, isError) = call(name, arguments: params["arguments"] as? [String: Any] ?? [:])
            response["result"] = ["content": [["type": "text", "text": text]], "isError": isError]
        default:
            response["error"] = Self.error(-32601, "Method not found")
        }
        return Self.encode(response)
    }

    private static func error(_ code: Int, _ message: String) -> [String: Any] {
        ["code": code, "message": message]
    }

    private static func encode(_ object: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return data.flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
    }

    // MARK: Tools

    private static var tools: [[String: Any]] {
        [
            [
                "name": "list_recordings",
                "description":
                    "Lists Meety recordings, newest first: id, date, title, participants, available transcripts. "
                    + "With `query`, only recordings whose title, participants or transcript contain every word.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string"],
                        "limit": ["type": "integer", "description": "Default 20"],
                    ],
                ],
            ],
            [
                "name": "get_transcript",
                "description":
                    "Full transcript of a recording (falls back to the live transcript when there is no final one).",
                "inputSchema": [
                    "type": "object",
                    "properties": ["id": ["type": "string", "description": "`id` from list_recordings"]],
                    "required": ["id"],
                ],
            ],
            [
                "name": "get_live_transcript",
                "description":
                    "Live transcript of the meeting being recorded right now (a few seconds to 30 s behind).",
                "inputSchema": ["type": "object", "properties": [String: Any]()],
            ],
        ]
    }

    private func call(_ name: String, arguments: [String: Any]) -> (String, Bool) {
        guard let directory else { return ("Recordings folder unavailable", true) }
        switch name {
        case "list_recordings":
            return (
                listRecordings(
                    in: directory, query: arguments["query"] as? String ?? "", limit: arguments["limit"] as? Int ?? 20),
                false
            )
        case "get_transcript":
            // Trust boundary: the id comes from the LLM, so it must be a plain recording filename.
            guard let id = arguments["id"] as? String, id == URL(fileURLWithPath: id).lastPathComponent,
                id.hasPrefix(Constants.Permissions.recordingPrefix + "_"),
                !id.hasSuffix(".partial.m4a")
            else { return ("Invalid id", true) }
            let audio = directory.appendingPathComponent(id)
            guard audio.pathExtension == Constants.Permissions.recordingExtension,
                FileManager.default.fileExists(atPath: audio.path)
            else { return ("Recording not found", true) }
            return transcript(of: audio)
        default:
            return liveTranscript(in: directory)
        }
    }

    private func listRecordings(in directory: URL, query: String, limit: Int) -> String {
        let entries = RecordingLibrary.load(CalendarMonitor.recordingsOnDisk(in: directory))
        let hits = RecordingLibrary.search(entries, query: query).prefix(max(limit, 1))
        let lines = hits.map { hit -> String in
            let entry = hit.entry
            let date = entry.date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "?"
            var line = "- id: \(entry.audio.lastPathComponent) | \(date) | \(entry.title ?? "(untitled)")"
            if !entry.participants.isEmpty { line += " | with " + entry.participants.joined(separator: ", ") }
            line +=
                " | transcript: \(entry.transcript == nil ? "no" : "yes"), live: \(entry.live == nil ? "no" : "yes")"
            if let snippet = hit.snippet { line += "\n  " + snippet }
            return line
        }
        return lines.isEmpty ? "No recording found." : lines.joined(separator: "\n")
    }

    private func transcript(of audio: URL) -> (String, Bool) {
        let files = RecordingFiles(audio: audio)
        let final = try? String(contentsOf: files.transcriptText, encoding: .utf8)
        guard let text = final ?? (try? String(contentsOf: files.liveTranscript, encoding: .utf8)) else {
            return ("No transcript for this recording.", true)
        }
        return ((final == nil ? "(live transcript, no final one yet)\n\n" : "") + text, false)
    }

    private func liveTranscript(in directory: URL) -> (String, Bool) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let partials =
            ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".partial.m4a") }
            .compactMap { url -> (URL, Date)? in
                guard let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate,
                    -modified.timeIntervalSinceNow < Self.liveFreshness
                else { return nil }
                return (url, modified)
            }
        guard let current = partials.max(by: { $0.1 < $1.1 })?.0 else { return ("No recording in progress.", false) }
        let name = current.lastPathComponent.replacingOccurrences(of: ".partial.m4a", with: ".m4a")
        let audio = directory.appendingPathComponent(name)
        let title = RecordingLibrary.titleFromFilename(name).map { " — \($0)" } ?? ""
        let text = (try? String(contentsOf: RecordingFiles(audio: audio).liveTranscript, encoding: .utf8)) ?? ""
        return (
            "Recording in progress\(title) (\(name))\n\n" + (text.isEmpty ? "(nothing transcribed yet)" : text), false
        )
    }
}
