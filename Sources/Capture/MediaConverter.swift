import Foundation
import AVFoundation

/// Converts the recorded MOV into an M4A (audio-only) via AVAssetExportSession.
///
/// Stateless and `Sendable`. File-system probes and the sleep function are
/// injectable so the stability wait can be unit-tested without real delays.
struct MediaConverter: Sendable {

    enum ConversionError: Error, LocalizedError {
        case fileNotReady(String)
        case noAudioTrack
        case exportSessionUnavailable

        var errorDescription: String? {
            switch self {
            case .fileNotReady(let path):
                return "Source file missing or incomplete: \(path)"
            case .noAudioTrack:
                return "No audio track found in the file."
            case .exportSessionUnavailable:
                return "Unable to create the export session."
            }
        }
    }

    var sleep: @Sendable (TimeInterval) async -> Void = { seconds in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    var fileSize: @Sendable (URL) -> UInt64? = { url in
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.uint64Value
    }
    var fileExists: @Sendable (URL) -> Bool = { url in
        FileManager.default.fileExists(atPath: url.path)
    }
    /// True when the file can be opened as media with a valid, positive duration.
    var isPlayable: @Sendable (URL) async -> Bool = { url in
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            return duration.isValid && duration.seconds > 0
        } catch {
            return false
        }
    }
    /// Clock, injectable for tests.
    var now: @Sendable () -> Date = { Date() }

    init() {}

    /// Wait for the MOV to be stable on disk, then export audio to M4A.
    ///
    /// `SCRecordingOutput` writes asynchronously: the file can exist while its
    /// moov atom is not finalized yet. We require a stable size for
    /// `converterStabilityRequiredChecks` consecutive probes AND a valid,
    /// positive duration before exporting (max `converterMaxWaitTime`).
    func convertToM4A(_ sourceURL: URL) async throws -> URL {
        try await waitForReadiness(of: sourceURL)

        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        Logger.shared.info("Asset loaded, duration: \(CMTimeGetSeconds(duration))s", component: "CONVERSION")

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw ConversionError.noAudioTrack
        }
        Logger.shared.info("Found \(audioTracks.count) audio track(s)", component: "CONVERSION")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.exportSessionUnavailable
        }

        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension("m4a")
        if fileExists(outputURL) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        Logger.shared.info("Starting export to: \(outputURL.lastPathComponent)", component: "CONVERSION")
        try await exportSession.export(to: outputURL, as: .m4a)
        Logger.shared.info("Converted successfully to M4A: \(outputURL.lastPathComponent)", component: "CONVERSION")
        return outputURL
    }

    /// Pre-flight wait: file exists, size stable, duration loadable and > 0.
    /// Internal (not private) so tests can drive it with injected probes.
    func waitForReadiness(of sourceURL: URL) async throws {
        let maxWait = Constants.Recording.converterMaxWaitTime
        let interval = Constants.Recording.fileStabilityCheckInterval
        let deadline = now().addingTimeInterval(maxWait)
        var lastSize: UInt64 = 0
        var stableCount = 0

        Logger.shared.info("Waiting for MOV to stabilize (max \(Int(maxWait))s)...", component: "CONVERSION")

        while now() < deadline {
            if fileExists(sourceURL), let currentSize = fileSize(sourceURL) {
                if currentSize > 0 && currentSize == lastSize {
                    stableCount += 1
                } else {
                    stableCount = 0
                    lastSize = currentSize
                }
            } else {
                stableCount = 0
                lastSize = 0
            }

            if stableCount >= Constants.Recording.converterStabilityRequiredChecks,
               await isPlayable(sourceURL) {
                return // ready
            }

            await sleep(interval)
        }

        throw ConversionError.fileNotReady(sourceURL.path)
    }
}
