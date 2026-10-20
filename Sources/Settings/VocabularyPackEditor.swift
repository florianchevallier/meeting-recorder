import AppKit
import SwiftUI

// MARK: - Vocabulary Pack Editor

struct VocabularyPackEditor: View {
    private let pack: CustomVocabularyPack
    private let isNew: Bool
    private let onSave: (CustomVocabularyPack) -> Void
    private let onDelete: () -> Void
    @State private var name: String
    @State private var termsText: String
    @Environment(\.dismiss) private var dismiss

    init(
        pack: CustomVocabularyPack, isNew: Bool, onSave: @escaping (CustomVocabularyPack) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.pack = pack
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        self._name = State(initialValue: pack.name)
        self._termsText = State(initialValue: pack.terms.joined(separator: "\n"))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var terms: [String] {
        CustomVocabularyPack.parse(termsText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? L10n.settingsPackEditorTitleNew : L10n.settingsPackEditorTitleEdit)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.settingsPackEditorName)
                    .font(.system(size: 12, weight: .medium))
                TextField(L10n.settingsPackEditorNamePlaceholder, text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.settingsPackEditorTerms)
                    .font(.system(size: 12, weight: .medium))
                TextField(L10n.settingsPackEditorTermsPlaceholder, text: $termsText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(5...10)
                Text(L10n.settingsPackEditorHelp)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                if !isNew {
                    Button(L10n.settingsTranscriptionPacksDelete, role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }

                Spacer()

                Button(L10n.settingsPackEditorCancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(L10n.settingsPackEditorSave) {
                    onSave(CustomVocabularyPack(id: pack.id, name: trimmedName, terms: terms))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty || terms.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
