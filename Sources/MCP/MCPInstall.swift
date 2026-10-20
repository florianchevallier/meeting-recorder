import Foundation

/// What the user pastes to plug an MCP client into this copy of Meety (`MeetingRecorder mcp`).
enum MCPInstall {
    /// `claude mcp add meety -- <executable> mcp`
    static func claudeCodeCommand(executable: String) -> String {
        "claude mcp add meety -- \(shellQuoted(executable)) mcp"
    }

    /// Entry for the `mcpServers` object of `claude_desktop_config.json` and compatible clients.
    static func clientConfigJSON(executable: String) -> String {
        let config: [String: Any] = ["mcpServers": ["meety": ["command": executable, "args": ["mcp"]]]]
        let data = try? JSONSerialization.data(
            withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return data.flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
    }

    /// Single quotes only when the path has characters the shell would interpret.
    private static func shellQuoted(_ path: String) -> String {
        guard path.contains(where: { !($0.isASCII && ($0.isLetter || $0.isNumber)) && !"_./-".contains($0) }) else {
            return path
        }
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
