import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation

@available(macOS 12.3, *)
@MainActor
class ScreenAudioCapture: NSObject, @preconcurrency SCStreamDelegate {
    private var stream: SCStream?
    private var streamOutput: ScreenAudioStreamOutput?
    private let audioSampleBufferQueue = DispatchQueue(label: "com.meetingrecorder.audio.capture", qos: .userInitiated)
    private var isCapturing = false
    
    weak var delegate: ScreenAudioCaptureDelegate?
    
    func startCapture() async throws {
        guard !isCapturing else {
            Logger.shared.log("⚠️ [SCREEN_CAPTURE] Already capturing, ignoring start request")
            return
        }
        
        Logger.shared.log("🎥 [SCREEN_CAPTURE] Starting screen audio capture...")
        
        do {
            // Use shared manager to avoid conflicts with permission checks
            let display = try await ShareableContentManager.shared.getFirstDisplay()
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Using display: \(display.displayID)")
            
            // Create configuration with proper settings
            let config = SCStreamConfiguration()
            
            // Configure for optimal audio capture
            if #available(macOS 13.0, *) {
                config.capturesAudio = true
                config.sampleRate = 48000
                config.channelCount = 2
                config.excludesCurrentProcessAudio = true
                
                // Minimal video configuration for audio-only capture
                config.width = 1
                config.height = 1
                config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
                config.queueDepth = 3
                
                // Disable unnecessary visual features
                config.showsCursor = false
                
                if #available(macOS 14.0, *) {
                    config.shouldBeOpaque = false
                }
            }
            
            if #available(macOS 15.0, *) {
                config.captureMicrophone = false // We handle microphone separately
            }
            
            // Create content filter
            let filter = SCContentFilter(display: display, excludingWindows: [])
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Created content filter")
            
            // Create stream output
            let output = ScreenAudioStreamOutput()
            output.delegate = delegate
            output.capture = self
            self.streamOutput = output
            
            // Create stream with strong references
            let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
            self.stream = captureStream
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Created SCStream: \(ObjectIdentifier(captureStream))")
            
            // Verify stream is not nil before proceeding
            guard self.stream != nil else {
                Logger.shared.log("❌ [SCREEN_CAPTURE] Stream became nil immediately after creation!")
                throw AudioCaptureError.streamFailedToStart
            }
            
            // Add stream output based on macOS version
            if #available(macOS 13.0, *) {
                Logger.shared.log("🎥 [SCREEN_CAPTURE] Adding audio stream output (macOS 13+)")
                try captureStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            } else {
                Logger.shared.log("🎥 [SCREEN_CAPTURE] Adding screen stream output (macOS 12.3)")
                try captureStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: audioSampleBufferQueue)
            }
            
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Stream output added successfully")
            
            // Verify stream is still not nil
            guard let verifiedStream = self.stream else {
                Logger.shared.log("❌ [SCREEN_CAPTURE] Stream became nil after adding output!")
                throw AudioCaptureError.streamFailedToStart
            }
            
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Starting stream capture...")
            Logger.shared.log("🎥 [SCREEN_CAPTURE] Stream ID before start: \(ObjectIdentifier(verifiedStream))")
            
            // Start capture
            try await verifiedStream.startCapture()
            
            isCapturing = true
            Logger.shared.log("✅ [SCREEN_CAPTURE] Screen audio capture started successfully")
            
        } catch {
            Logger.shared.log("❌ [SCREEN_CAPTURE] Failed to start capture: \(error)")
            
            // Clean up on failure
            await cleanupStream()
            
            // Convert specific errors
            if let scError = error as? SCStreamError {
                Logger.shared.log("❌ [SCREEN_CAPTURE] SCStreamError code: \(scError.code)")
                switch scError.code {
                case .failedToStart:
                    throw AudioCaptureError.streamFailedToStart
                case .failedToStartAudioCapture:
                    throw AudioCaptureError.audioStreamFailedToStart
                case .internalError:
                    throw AudioCaptureError.screenCaptureInternalError
                case .noCaptureSource:
                    throw AudioCaptureError.noCaptureSource
                default:
                    throw AudioCaptureError.captureInitializationFailed
                }
            } else if error is ShareableContentError {
                throw AudioCaptureError.noDisplayFound
            }
            
            throw error
        }
    }
    
    func stopCapture() {
        Task {
            await cleanupStream()
        }
    }
    
    private func cleanupStream() async {
        guard isCapturing else { return }
        
        Logger.shared.log("🛑 [SCREEN_CAPTURE] Stopping screen audio capture...")
        
        if let captureStream = stream {
            do {
                try await captureStream.stopCapture()
                Logger.shared.log("✅ [SCREEN_CAPTURE] Stream stopped successfully")
            } catch {
                Logger.shared.log("⚠️ [SCREEN_CAPTURE] Error stopping stream: \(error)")
            }
        }
        
        stream = nil
        streamOutput = nil
        isCapturing = false
        
        Logger.shared.log("🧹 [SCREEN_CAPTURE] Cleanup completed")
    }
    
    // MARK: - SCStreamDelegate
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("❌ [STREAM_DELEGATE] Stream stopped with error: \(error)")
        
        // Handle specific error cases
        if let scError = error as? SCStreamError {
            Logger.shared.log("❌ [STREAM_DELEGATE] SCStreamError code: \(scError.code)")
            
            // Check if it's a user-initiated stop (not actually an error)
            if #available(macOS 15.0, *) {
                if scError.code == .systemStoppedStream {
                    Logger.shared.log("ℹ️ [STREAM_DELEGATE] System stopped stream (not an error)")
                }
            }
        }
        
        // Reset state
        Task { @MainActor in
            await cleanupStream()
        }
    }
}

@available(macOS 12.3, *)
protocol ScreenAudioCaptureDelegate: AnyObject {
    func screenAudioCapture(_ capture: ScreenAudioCapture, didReceiveAudioSampleBuffer sampleBuffer: CMSampleBuffer) async
}

@available(macOS 12.3, *)
class ScreenAudioStreamOutput: NSObject, SCStreamOutput {
    weak var delegate: ScreenAudioCaptureDelegate?
    weak var capture: ScreenAudioCapture?
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if #available(macOS 13.0, *) {
            guard type == .audio else { return }
        }
        
        // Process audio sample buffer
        guard let capture = capture else { return }
        Task { @MainActor in
            await delegate?.screenAudioCapture(capture, didReceiveAudioSampleBuffer: sampleBuffer)
        }
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case noDisplayFound
    case permissionDenied
    case captureInitializationFailed
    case streamFailedToStart
    case audioStreamFailedToStart
    case screenCaptureInternalError
    case noCaptureSource
    
    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No displays found for screen capture"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .captureInitializationFailed:
            return "Failed to initialize screen capture"
        case .streamFailedToStart:
            return "ScreenCaptureKit stream failed to start"
        case .audioStreamFailedToStart:
            return "Audio stream failed to start"
        case .screenCaptureInternalError:
            return "ScreenCaptureKit internal error"
        case .noCaptureSource:
            return "No capture source available"
        }
    }
}