import SwiftUI

/// Ready-made and custom vocabulary packs as toggle buttons, with the pack editor sheet.
struct VocabularyPacksField: View {
    @Bindable var settings: SettingsStore
    @State private var editingPack: CustomVocabularyPack?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(VocabularyPack.allCases) { pack in
                Toggle(isOn: packBinding(pack.rawValue)) {
                    Label(pack.title, systemImage: pack.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.button)
                .help(pack.terms.joined(separator: ", "))
            }

            ForEach(settings.customVocabularyPacks) { pack in
                Toggle(isOn: packBinding(pack.id)) {
                    Label(pack.name, systemImage: "star.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.button)
                .help(pack.terms.joined(separator: ", "))
                .contextMenu {
                    Button(L10n.settingsTranscriptionPacksEdit) { editingPack = pack }
                    Button(L10n.settingsTranscriptionPacksDelete, role: .destructive) {
                        settings.deleteCustomPack(id: pack.id)
                    }
                }
            }

            Button {
                editingPack = CustomVocabularyPack()
            } label: {
                Label(L10n.settingsTranscriptionPacksNew, systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(item: $editingPack) { pack in
            VocabularyPackEditor(
                pack: pack,
                isNew: !settings.customVocabularyPacks.contains { $0.id == pack.id },
                onSave: { settings.saveCustomPack($0) },
                onDelete: { settings.deleteCustomPack(id: pack.id) }
            )
        }
    }

    private func packBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { settings.vocabularyPacks.contains(id) },
            set: { isOn in
                if isOn {
                    settings.vocabularyPacks.insert(id)
                } else {
                    settings.vocabularyPacks.remove(id)
                }
            }
        )
    }
}
