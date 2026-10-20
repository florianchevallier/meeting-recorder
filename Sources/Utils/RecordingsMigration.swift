import os
import Foundation

/// Moves the recordings written to `~/Documents` before 0.8 into the Application
/// Support folder. Runs at every launch; a no-op once nothing is left.
enum RecordingsMigration {

    /// A group touched more recently than this may still be written by another
    /// Meety instance (e.g. the release app recording while the debug build launches).
    static let quietPeriod: TimeInterval = 10 * 60

    /// Sidecar suffixes, longest first, so `x.partial.m4a` groups with `x.m4a`.
    private static let suffixes = [
        ".transcription-job.json", ".transcript.json", ".activity.json", ".speakers.json",
        ".meeting.json", ".partial.m4a", ".live.md", ".txt",
    ]

    static func migrate(from source: URL, to destination: URL, now: Date = Date()) {
        let fileManager = FileManager.default
        let prefix = Constants.Permissions.recordingPrefix + "_"
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: source, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        else { return }

        let groups = Dictionary(grouping: files.filter { $0.lastPathComponent.hasPrefix(prefix) }, by: groupKey)
        var moved = 0
        for (key, group) in groups {
            let isBusy = group.contains {
                let modified = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return modified.map { now.timeIntervalSince($0) < quietPeriod } ?? false
            }
            if isBusy {
                Log.app.info("Migration: \(key, privacy: .private) still being written, left for next launch")
                continue
            }
            for file in group {
                let target = destination.appendingPathComponent(file.lastPathComponent)
                // Never overwrite: a name clash keeps both copies for the user to sort out.
                guard !fileManager.fileExists(atPath: target.path) else { continue }
                do {
                    try fileManager.moveItem(at: file, to: target)
                    moved += 1
                } catch {
                    Log.app.error(
                        "Migration of \(file.lastPathComponent, privacy: .private) failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
        if moved > 0 {
            Log.app.info("Migrated \(moved) recording files to \(destination.path, privacy: .public)")
        }
    }

    /// The recording a file belongs to: its name without the sidecar suffix.
    static func groupKey(_ file: URL) -> String {
        let name = file.lastPathComponent
        if let suffix = suffixes.first(where: { name.hasSuffix($0) }) {
            return String(name.dropLast(suffix.count))
        }
        return file.deletingPathExtension().lastPathComponent
    }
}
