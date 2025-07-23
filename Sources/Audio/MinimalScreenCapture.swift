import Foundation
import ScreenCaptureKit
import AVFoundation

/// Implémentation ultra-minimaliste basée exactement sur les exemples officiels Apple
@available(macOS 12.3, *)
@MainActor
final class MinimalScreenCapture: NSObject, ObservableObject {
    private var stream: SCStream?
    private var audioOutput: MinimalAudioOutput?
    @Published var isRecording = false
    
    // Callback simple pour recevoir l'audio
    var onAudioReceived: ((CMSampleBuffer) -> Void)?
    
    func start() async throws {
        print("🎯 Starting minimal screen capture...")
        
        // 1. Get content - exemple direct d'Apple
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, 
            onScreenWindowsOnly: true
        )
        
        guard let display = content.displays.first else {
            throw NSError(domain: "MinimalCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No display available"
            ])
        }
        
        print("🎯 Display found: \(display.displayID)")
        
        // 2. Configuration ultra-simple avec vérifications de version
        let config = SCStreamConfiguration()
        
        // Configuration audio (macOS 13+)
        if #available(macOS 13.0, *) {
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
        }
        
        // Video minimal pour satisfaire l'API
        config.width = 100
        config.height = 100
        config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
        config.showsCursor = false
        
        print("🎯 Config created")
        
        // 3. Filter - capture tout l'audio du display
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // 4. Output handler
        let output = MinimalAudioOutput()
        output.onAudioReceived = onAudioReceived
        audioOutput = output
        
        // 5. Stream creation - pattern exact d'Apple
        let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
        stream = captureStream
        
        print("🎯 Stream created")
        
        // 6. Add output avec vérification de version
        if #available(macOS 13.0, *) {
            try captureStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .main)
            print("🎯 Audio output added")
        } else {
            try captureStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
            print("🎯 Screen output added (fallback)")
        }
        
        // 7. Start - pattern exact d'Apple
        try await captureStream.startCapture()
        print("🎯 ✅ Capture started successfully!")
        
        isRecording = true
    }
    
    func stop() async {
        guard let captureStream = stream, isRecording else { return }
        
        do {
            try await captureStream.stopCapture()
            print("🎯 ✅ Capture stopped")
        } catch {
            print("🎯 ⚠️ Stop error: \(error)")
        }
        
        stream = nil
        audioOutput = nil
        isRecording = false
    }
}

// MARK: - SCStreamDelegate
@available(macOS 12.3, *)
extension MinimalScreenCapture: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("🎯 ❌ Stream error: \(error)")
        
        Task { @MainActor in
            self.isRecording = false
            self.stream = nil
            self.audioOutput = nil
        }
    }
}

// MARK: - Audio Output Handler
@available(macOS 12.3, *)
final class MinimalAudioOutput: NSObject, SCStreamOutput {
    var onAudioReceived: ((CMSampleBuffer) -> Void)?
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Filtrer selon la version de macOS
        if #available(macOS 13.0, *) {
            guard type == .audio else { return }
        }
        // Pour macOS 12.3, on accepte tous les types (screen inclut l'audio)
        
        Task { @MainActor in
            onAudioReceived?(sampleBuffer)
        }
    }
}