import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation

/// Ultra-minimal ScreenCaptureKit implementation based on Apple's official examples
@available(macOS 12.3, *)
@MainActor
class SimpleScreenCapture: NSObject, @preconcurrency SCStreamDelegate {
    private var stream: SCStream?
    private var streamOutput: SimpleStreamOutput?
    
    weak var delegate: SimpleScreenCaptureDelegate?
    
    func startCapture() async throws {
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] Starting ultra-minimal screen capture...")
        
        // Step 1: Get content (using Apple's exact pattern)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw SimpleScreenCaptureError.noDisplayFound
        }
        
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] Got display: \(display.displayID)")
        
        // Step 2: Create audio-optimized configuration
        let config = SCStreamConfiguration()
        
        // Minimal video settings for audio-only capture
        config.width = 1
        config.height = 1
        config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1) // Very low frame rate
        config.queueDepth = 3
        
        // Optimize for audio capture
        if #available(macOS 13.0, *) {
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.excludesCurrentProcessAudio = true // Important: don't capture our own app
        }
        
        // Disable unnecessary visual features
        config.showsCursor = false
        if #available(macOS 14.0, *) {
            config.shouldBeOpaque = false
        }
        
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] Created configuration")
        
        // Step 3: Create content filter (Apple's exact pattern)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] Created filter")
        
        // Step 4: Create stream output
        let output = SimpleStreamOutput()
        output.delegate = delegate
        streamOutput = output
        
        // Step 5: Create stream (Apple's exact pattern - self is the delegate)
        let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
        stream = captureStream
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] Created stream: \(ObjectIdentifier(captureStream))")
        
        // Step 6: Add output (Apple's exact pattern)
        do {
            if #available(macOS 13.0, *) {
                try captureStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue.main)
                Logger.shared.log("🔬 [SIMPLE_CAPTURE] Added audio output")
            } else {
                try captureStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.main)
                Logger.shared.log("🔬 [SIMPLE_CAPTURE] Added screen output")
            }
        } catch {
            Logger.shared.log("❌ [SIMPLE_CAPTURE] Failed to add output: \(error)")
            throw error
        }
        
        // Step 7: Start capture (Apple's exact pattern)
        Logger.shared.log("🔬 [SIMPLE_CAPTURE] About to start capture...")
        
        do {
            try await captureStream.startCapture()
            Logger.shared.log("✅ [SIMPLE_CAPTURE] SUCCESS! Stream started")
        } catch {
            Logger.shared.log("❌ [SIMPLE_CAPTURE] Failed to start: \(error)")
            Logger.shared.log("❌ [SIMPLE_CAPTURE] Stream reference: \(stream == nil ? "nil" : "valid")")
            Logger.shared.log("❌ [SIMPLE_CAPTURE] Stream ID: \(ObjectIdentifier(captureStream))")
            throw error
        }
    }
    
    func stopCapture() async {
        if let captureStream = stream {
            do {
                try await captureStream.stopCapture()
                Logger.shared.log("✅ [SIMPLE_CAPTURE] Stopped successfully")
            } catch {
                Logger.shared.log("⚠️ [SIMPLE_CAPTURE] Stop error: \(error)")
            }
        }
        
        stream = nil
        streamOutput = nil
    }
    
    // MARK: - SCStreamDelegate
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("❌ [SIMPLE_CAPTURE_DELEGATE] Stream stopped with error: \(error)")
        
        // Reset state on main actor
        Task { @MainActor in
            self.stream = nil
            self.streamOutput = nil
        }
    }
}

@available(macOS 12.3, *)
class SimpleStreamOutput: NSObject, SCStreamOutput {
    weak var delegate: SimpleScreenCaptureDelegate?
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if #available(macOS 13.0, *) {
            guard type == .audio else { return }
        }
        
        Task { @MainActor in
            await delegate?.simpleScreenCapture(didReceiveAudioSampleBuffer: sampleBuffer)
        }
    }
}

@available(macOS 12.3, *)
protocol SimpleScreenCaptureDelegate: AnyObject {
    func simpleScreenCapture(didReceiveAudioSampleBuffer sampleBuffer: CMSampleBuffer) async
}

enum SimpleScreenCaptureError: Error {
    case noDisplayFound
}