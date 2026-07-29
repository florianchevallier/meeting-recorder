import Testing
import Foundation

/// Guards that both localization files stay in sync. Reads the .strings files
/// directly from the repo (they live in the app target's resources, not the
/// test bundle).
@Suite("L10n parity")
struct L10nParityTests {

    private func keys(forLocale locale: String) throws -> Set<String> {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let stringsURL = repoRoot
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
}
