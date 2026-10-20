import AppKit
import SwiftUI

/// Settings → AI assistants: how to plug Claude Code / Claude Desktop into `MeetingRecorder mcp`.
struct MCPSettingsTab: View {
    /// The running binary, so the command points at this copy of Meety (installed or debug build).
    private let executable = Bundle.main.executablePath ?? "/Applications/Meety.app/Contents/MacOS/MeetingRecorder"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "sparkles",
                    gradientColors: [.purple, .pink],
                    title: L10n.settingsMcpHeaderTitle,
                    subtitle: L10n.settingsMcpHeaderSubtitle
                )

                SettingsCard {
                    Text(L10n.settingsMcpToolsTitle).font(.headline)
                    Text(L10n.settingsMcpToolsBody).foregroundStyle(.secondary)
                }

                SettingsCard {
                    Text(L10n.settingsMcpClaudeCodeTitle).font(.headline)
                    Text(L10n.settingsMcpClaudeCodeSubtitle).foregroundStyle(.secondary)
                    CodeBlock(text: MCPInstall.claudeCodeCommand(executable: executable))
                }

                SettingsCard {
                    Text(L10n.settingsMcpDesktopTitle).font(.headline)
                    Text(L10n.settingsMcpDesktopSubtitle).foregroundStyle(.secondary)
                    CodeBlock(text: MCPInstall.clientConfigJSON(executable: executable))
                }

                Text(L10n.settingsMcpNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

/// Selectable monospaced text with a Copy button.
private struct CodeBlock: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? L10n.settingsMcpCopied : L10n.settingsMcpCopy, action: copy)
        }
        .padding(12)
        .background(Color(.textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
