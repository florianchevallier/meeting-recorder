import Foundation
import CoreAudio

/// Publishes default-device / device-list changes as an `AsyncStream`.
/// Listener blocks run on a private queue and only yield into the stream.
final class DeviceChangeObserver {
    enum Change: Sendable, Equatable {
        case defaultInput
        case defaultOutput
        case deviceList
    }

    let changes: AsyncStream<Change>
    private let continuation: AsyncStream<Change>.Continuation
    private let queue = DispatchQueue(label: "com.meetingrecorder.meety.capture.devices")
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init() {
        (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
    }

    func start() {
        guard listeners.isEmpty else { return }
        register(kAudioHardwarePropertyDefaultInputDevice, change: .defaultInput)
        register(kAudioHardwarePropertyDefaultOutputDevice, change: .defaultOutput)
        register(kAudioHardwarePropertyDevices, change: .deviceList)
    }

    func invalidate() {
        for (address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, block)
        }
        listeners.removeAll()
        continuation.finish()
    }

    private func register(_ selector: AudioObjectPropertySelector, change: Change) {
        var address = CoreAudioProperties.address(selector)
        let continuation = self.continuation
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            continuation.yield(change)
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, block)
        if status == noErr {
            listeners.append((address, block))
        }
    }

    /// Human-readable default devices, for logs.
    static func snapshotDescription() -> String {
        let output =
            (try? CoreAudioProperties.defaultDevice(input: false)).map(CoreAudioProperties.deviceName) ?? "none"
        let input = (try? CoreAudioProperties.defaultDevice(input: true)).map(CoreAudioProperties.deviceName) ?? "none"
        return "output=\(output) input=\(input)"
    }
}
