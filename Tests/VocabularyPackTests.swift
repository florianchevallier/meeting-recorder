import Testing
import Foundation
@testable import MeetingRecorder

@Suite("VocabularyPack")
struct VocabularyPackTests {

    @Test("Selected packs give their terms in declaration order, deduplicated")
    func terms() {
        let terms = VocabularyPack.terms(for: ["devops", "development", "unknown"])
        #expect(terms.first == "API")
        #expect(terms.contains("Kubernetes"))
        #expect(Set(terms.map { $0.lowercased() }).count == terms.count)
        #expect(VocabularyPack.terms(for: []).isEmpty)
    }

    @Test("Custom packs come before the built-in ones")
    func customFirst() {
        let mine = CustomVocabularyPack(id: "mine", name: "Client", terms: ["Atecna", "api"])
        let terms = VocabularyPack.terms(for: ["mine", "development"], custom: [mine])
        #expect(Array(terms.prefix(2)) == ["Atecna", "api"])
        #expect(!terms.contains("API"))  // deduplicated case-insensitively
        #expect(VocabularyPack.terms(for: ["development"], custom: [mine]).first == "API")
    }

    @Test("Terms are split on lines, commas and semicolons, trimmed, empties dropped")
    func parse() {
        #expect(CustomVocabularyPack.parse("Meety, WhisperX;\n  pyannote \n\n,") == ["Meety", "WhisperX", "pyannote"])
    }

    @Test("Every pack fits in the prompt on its own and has a localized title")
    func packs() {
        for pack in VocabularyPack.allCases {
            #expect(pack.terms.joined(separator: ", ").count < TranscriptionHints.maxPromptLength / 2)
            #expect(pack.title != "vocabulary.pack.\(pack.rawValue)")
        }
    }
}
