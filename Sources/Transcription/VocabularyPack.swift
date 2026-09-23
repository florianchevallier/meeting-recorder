import Foundation

/// Ready-made vocabulary added to the WhisperX prompt, so common jargon is
/// spelled right without typing it. Kept short: the whole prompt is capped
/// at `TranscriptionHints.maxPromptLength`, and packs come last.
enum VocabularyPack: String, CaseIterable, Identifiable, Sendable {
    case development
    case devops
    case agile
    case data
    case design
    case business

    var id: String { rawValue }

    var title: String {
        L10n.string("vocabulary.pack.\(rawValue)")
    }

    var icon: String {
        switch self {
        case .development: "chevron.left.forwardslash.chevron.right"
        case .devops: "cloud.fill"
        case .agile: "arrow.triangle.2.circlepath"
        case .data: "brain.head.profile"
        case .design: "paintpalette.fill"
        case .business: "briefcase.fill"
        }
    }

    var terms: [String] {
        switch self {
        case .development:
            [
                "API", "backend", "frontend", "pull request", "merge", "commit", "refacto", "hotfix", "TypeScript",
                "React", "Node.js", "Swift",
            ]
        case .devops:
            [
                "CI/CD", "pipeline", "Kubernetes", "Docker", "Terraform", "AWS", "Azure", "GCP", "staging", "prod",
                "Grafana",
            ]
        case .agile:
            [
                "sprint", "backlog", "user story", "story points", "daily", "rétro", "PO", "Scrum Master", "Jira",
                "Confluence", "MVP", "recette",
            ]
        case .data:
            [
                "LLM", "IA générative", "prompt", "RAG", "embeddings", "fine-tuning", "machine learning", "dataset",
                "ETL", "Python",
            ]
        case .design:
            [
                "UX", "UI", "Figma", "maquette", "wireframe", "prototype", "design system", "parcours utilisateur",
                "RGAA", "persona",
            ]
        case .business:
            [
                "avant-vente", "appel d'offres", "chiffrage", "TJM", "jours-homme", "forfait", "régie", "devis",
                "go/no-go", "KPI",
            ]
        }
    }

    /// Terms of the selected packs without duplicates: the user's own packs first (more
    /// specific, so the prompt cut spares them), then the built-in ones in declaration order.
    static func terms(for selection: Set<String>, custom: [CustomVocabularyPack] = []) -> [String] {
        var seen = Set<String>()
        let customTerms = custom.filter { selection.contains($0.id) }.flatMap(\.terms)
        let builtInTerms = allCases.filter { selection.contains($0.rawValue) }.flatMap(\.terms)
        return (customTerms + builtInTerms).filter { seen.insert($0.lowercased()).inserted }
    }
}

/// A pack the user made in Settings → Transcription. Its `id` (a UUID) shares the
/// selection set with the built-in raw values.
struct CustomVocabularyPack: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var terms: [String]

    init(id: String = UUID().uuidString, name: String = "", terms: [String] = []) {
        self.id = id
        self.name = name
        self.terms = terms
    }

    /// Terms typed one per line or separated by commas or semicolons.
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
