import Testing
import Foundation
import CoreAudio
@testable import MeetingRecorder

@Suite("CaptureErrorClassifier")
struct CaptureErrorClassifierTests {

    @Test(
        "Transient Core Audio statuses restart the tap",
        arguments: [
            kAudioHardwareBadDeviceError, kAudioHardwareBadObjectError, kAudioHardwareBadStreamError,
            kAudioHardwareNotRunningError, kAudioHardwareNotReadyError, kAudioDeviceUnsupportedFormatError,
        ])
    func restartable(status: OSStatus) {
        #expect(CaptureErrorClassifier.policy(for: .coreAudio(status: status, operation: "x")) == .restartTap)
    }

    @Test(
        "Other Core Audio statuses are fatal",
        arguments: [
            kAudioHardwareIllegalOperationError, kAudioHardwareUnsupportedOperationError,
            kAudioDevicePermissionsError, OSStatus(-1),
        ])
    func fatalStatuses(status: OSStatus) {
        #expect(CaptureErrorClassifier.policy(for: .coreAudio(status: status, operation: "x")) == .fatal)
    }

    @Test("Stalls and tap unavailability restart; everything else is fatal")
    func semanticFailures() {
        #expect(CaptureErrorClassifier.policy(for: .stalled) == .restartTap)
        #expect(CaptureErrorClassifier.policy(for: .tapUnavailable) == .restartTap)
        #expect(CaptureErrorClassifier.policy(for: .writer("x")) == .fatal)
        #expect(CaptureErrorClassifier.policy(for: .diskFull) == .fatal)
        #expect(CaptureErrorClassifier.policy(for: .systemAudioAccessDenied) == .fatal)
        #expect(CaptureErrorClassifier.policy(for: .noOutputDevice) == .fatal)
    }

    @Test("OSStatus renders as FourCC when printable")
    func fourCC() {
        #expect(kAudioHardwareBadDeviceError.fourCharCode == "'!dev'")
        #expect(kAudioHardwareNotRunningError.fourCharCode == "'stop'")
        #expect(OSStatus(-1).fourCharCode == "-1")
        #expect(OSStatus(0).fourCharCode == "0")
    }
}
