import Foundation
import AVFoundation

class PermissionManager {
    
    func requestMicrophonePermission() async throws {
        let granted = await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
        
        if !granted {
            throw PermissionError.microphonePermissionDenied
        }
    }
    
    func checkMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}

enum PermissionError: Error, LocalizedError {
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "L'accès au microphone est requis pour enregistrer. Veuillez autoriser l'accès dans les Préférences Système."
        }
    }
}