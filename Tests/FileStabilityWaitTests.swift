import Testing
import Foundation
@testable import MeetingRecorder

@Suite("File stability wait")
struct FileStabilityWaitTests {

    /// Mutable box to drive the injected probes (test-local, lock-free by design).
    private final class Box<T>: @unchecked Sendable {
        var value: T
        init(_ value: T) { self.value = value }
    }

    private let dummyURL = URL(fileURLWithPath: "/tmp/fake.mov")

    @Test("Returns once the size is stable and the file is playable")
    func readyWhenStable() async throws {
        let sizes = Box([UInt64(100), 200, 200, 200, 200])
        var converter = MediaConverter()
        converter.sleep = { _ in }
        converter.now = { Date() }
        converter.fileExists = { _ in true }
        converter.fileSize = { _ in
            sizes.value.count > 1 ? sizes.value.removeFirst() : sizes.value[0]
        }
        converter.isPlayable = { _ in true }

        try await converter.waitForReadiness(of: dummyURL) // must not throw
    }

    @Test("Waits while the file keeps growing")
    func waitsWhileGrowing() async throws {
        // Grows for 4 checks, then stabilizes — must succeed only after stability
        let sizes = Box([UInt64(100), 200, 300, 400, 400, 400, 400])
        var converter = MediaConverter()
        converter.sleep = { _ in }
        converter.now = { Date() }
        converter.fileExists = { _ in true }
        converter.fileSize = { _ in
            sizes.value.count > 1 ? sizes.value.removeFirst() : sizes.value[0]
        }
        converter.isPlayable = { _ in true }

        try await converter.waitForReadiness(of: dummyURL)
        #expect(sizes.value.count <= 3, "returned before the size stabilized")
    }

    @Test("Throws after the deadline when the file never stabilizes")
    func timeout() async {
        let currentTime = Box(Date())
        let size = Box(UInt64(0))

        var converter = MediaConverter()
        converter.now = { currentTime.value }
        converter.sleep = { seconds in
            currentTime.value = currentTime.value.addingTimeInterval(seconds)
        }
        converter.fileExists = { _ in true }
        converter.fileSize = { _ in
            size.value += 100 // always growing, never stable
            return size.value
        }
        converter.isPlayable = { _ in true }

        await #expect(throws: MediaConverter.ConversionError.self) {
            try await converter.waitForReadiness(of: dummyURL)
        }
    }

    @Test("Throws after the deadline when the media is never readable")
    func notPlayable() async {
        let currentTime = Box(Date())

        var converter = MediaConverter()
        converter.now = { currentTime.value }
        converter.sleep = { seconds in
            currentTime.value = currentTime.value.addingTimeInterval(seconds)
        }
        converter.fileExists = { _ in true }
        converter.fileSize = { _ in 500 } // stable size…
        converter.isPlayable = { _ in false } // …but moov atom never ready

        await #expect(throws: MediaConverter.ConversionError.self) {
            try await converter.waitForReadiness(of: dummyURL)
        }
    }
}
