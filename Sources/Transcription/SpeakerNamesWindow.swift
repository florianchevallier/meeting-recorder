import os
import Cocoa
import SwiftUI

/// Names the diarized speakers of one recording, then re-renders its `.txt`.
@MainActor
@Observable
final class SpeakerNamesModel {
    struct Speaker: Identifiable, Equatable {
        let id: String
        /// Longest thing this speaker said, to recognize the voice.
        let sample: String
        let index: Int
    }

    let audioURL: URL
    let title: String
    let speakers: [Speaker]
    let participants: [String]
    var names: [String: String]

    init(document: TranscriptFiles.Document) {
        audioURL = document.files.audio
        title = document.event?.title ?? document.files.audio.deletingPathExtension().lastPathComponent
        participants = document.event?.expectedParticipants.map(\.displayName) ?? []
        names = document.names

        let turns = TranscriptRenderer.turns(in: document.transcript)
        speakers = document.transcript.speakers.enumerated().map { index, id in
            let longest = turns.filter { $0.speaker == id }.max { $0.text.count < $1.text.count }?.text ?? ""
            let sample = longest.count > 160 ? String(longest.prefix(160)) + "…" : longest
            return Speaker(id: id, sample: sample, index: index + 1)
        }
    }

    func binding(for id: String) -> Binding<String> {
        Binding(get: { self.names[id] ?? "" }, set: { self.names[id] = $0 })
    }
}

private struct SpeakerNamesView: View {
    @Bindable var model: SpeakerNamesModel
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(L10n.speakersHelp)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.speakers) { speaker in
                        row(speaker)
                        Divider()
                    }
                }
            }

            HStack {
                Spacer()
                Button(L10n.speakersCancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.speakersSave, action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
    }

    private func row(_ speaker: SpeakerNamesModel.Speaker) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(L10n.transcriptUnknownSpeaker(speaker.index))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                TextField(L10n.speakersNamePlaceholder, text: model.binding(for: speaker.id))
                    .textFieldStyle(.roundedBorder)

                if !model.participants.isEmpty {
                    Menu {
                        ForEach(model.participants, id: \.self) { name in
                            Button(name) { model.names[speaker.id] = name }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help(L10n.speakersParticipants)
                }
            }

            Text("“\(speaker.sample)”")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .italic()
                .lineLimit(3)
        }
    }
}

/// Owns the speaker-naming NSWindow (created once, content replaced per recording).
@MainActor
final class SpeakerNamesWindowController: NSObject {

    private var window: NSWindow?

    func show(for audioURL: URL) {
        let document: TranscriptFiles.Document
        do {
            document = try TranscriptFiles.load(for: audioURL)
        } catch {
            Log.transcription.error("Speakers not editable: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = L10n.speakersUnavailable
            alert.runModal()
            return
        }

        let model = SpeakerNamesModel(document: document)
        let rootView = SpeakerNamesView(
            model: model,
            onSave: { [weak self] in
                do {
                    try TranscriptFiles.saveNames(model.names, for: model.audioURL)
                    Log.transcription.info(
                        "Speaker names saved for \(model.audioURL.lastPathComponent, privacy: .public)")
                } catch {
                    Log.transcription.error("Speaker names not saved: \(error.localizedDescription, privacy: .public)")
                    NSSound.beep()
                    return
                }
                self?.window?.close()
            },
            onCancel: { [weak self] in self?.window?.close() }
        )

        let window = self.window ?? makeWindow()
        window.contentViewController = NSHostingController(rootView: rootView)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        self.window = window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.speakersWindowTitle
        window.isReleasedWhenClosed = false
        return window
    }
}
