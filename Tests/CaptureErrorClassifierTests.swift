import Testing
import Foundation
@testable import MeetingRecorder

@Suite("CaptureErrorClassifier")
struct CaptureErrorClassifierTests {

    @Test("Known recoverable ScreenCaptureKit codes", arguments: [-3821, -3812, -3801])
    func recoverable(code: Int) {
        let error = NSError(domain: "com.apple.ScreenCaptureKit", code: code)
        #expect(CaptureErrorClassifier.isRecoverable(error))
    }

    @Test("Other codes are not recoverable", arguments: [-1, -3804, -9999, 0])
    func notRecoverable(code: Int) {
        let error = NSError(domain: "com.apple.ScreenCaptureKit", code: code)
        #expect(!CaptureErrorClassifier.isRecoverable(error))
    }
}
