import Testing
import Foundation
@testable import MeetingRecorder

/// Guards that both localization files stay in sync. Reads the .strings files
/// directly from the repo (they live in the app target's resources, not the
/// test bundle).
@Suite("L10n parity")
struct L10nParityTests {

    private func keys(forLocale locale: String) throws -> Set<String> {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let stringsURL =
            repoRoot
            .appendingPathComponent("Sources/Resources/\(locale).lproj/Localizable.strings")

        guard let dictionary = try NSDictionary(contentsOf: stringsURL, error: ()) as? [String: String] else {
            Issue.record("Cannot parse \(stringsURL.path)")
            return []
        }
        return Set(dictionary.keys)
    }

    @Test("EN and FR key sets are identical")
    func keyParity() throws {
        let enKeys = try keys(forLocale: "en")
        let frKeys = try keys(forLocale: "fr")

        #expect(!enKeys.isEmpty)
        let missingInFr = enKeys.subtracting(frKeys)
        let missingInEn = frKeys.subtracting(enKeys)
        #expect(missingInFr.isEmpty, "Keys missing in fr.lproj: \(missingInFr.sorted())")
        #expect(missingInEn.isEmpty, "Keys missing in en.lproj: \(missingInEn.sorted())")
    }

    @Test("Every key referenced from Localization.swift exists in en.lproj")
    func referencedKeysExist() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/Utils/Localization.swift"), encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #""([a-z0-9_.]+)"\.localized|L10n\.string\("([a-z0-9_.]+)""#)
        let range = NSRange(source.startIndex..., in: source)
        var referenced = Set<String>()
        for match in regex.matches(in: source, range: range) {
            for group in 1...2 {
                if let r = Range(match.range(at: group), in: source) { referenced.insert(String(source[r])) }
            }
        }
        #expect(referenced.count > 50)
        let enKeys = try keys(forLocale: "en")
        let missing = referenced.subtracting(enKeys)
        #expect(missing.isEmpty, "Referenced but missing in en.lproj: \(missing.sorted())")
    }

    @Test("Format arguments flow through String.localized (regression: array passed as one CVarArg)")
    func formatSubstitution() {
        #expect(L10n.errorRecordingFailed("boom") == "Recording failed: boom")
        #expect(L10n.errorRecoveryAttempt(2, 3) == "Reconnecting audio (2/3)…")
    }
}
