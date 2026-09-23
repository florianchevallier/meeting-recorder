import Foundation
import CoreAudio
import Synchronization

/// Publishes default-device / device-list changes as an `AsyncStream`.
/// Listener blocks run on a private queue and only yield into the stream.
final class DeviceChangeObserver {
    enum Change: Sendable, Equatable {
        case defaultInput
        case defaultOutput
        case deviceList
        /// Nominal rate of the default input/output changed (Bluetooth A2DP ↔ hands-free).
        case sampleRate
    }

    let changes: AsyncStream<Change>
    private let continuation: AsyncStream<Change>.Continuation
    private let queue = DispatchQueue(label: "com.meetingrecorder.meety.capture.devices")
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    /// Devices other than our own aggregates, as last seen by the listeners.
    private final class KnownDevices: Sendable {
        let uids = Mutex<Set<String>>([])
    }
    private let knownDevices = KnownDevices()

    init() {
        (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
    }

    func start() {
        guard listeners.isEmpty else { return }
        knownDevices.uids.withLock { $0 = Self.externalDevices(CoreAudioProperties.deviceUIDs()) }
        register(kAudioHardwarePropertyDefaultInputDevice, change: .defaultInput)
        register(kAudioHardwarePropertyDefaultOutputDevice, change: .defaultOutput)
        register(kAudioHardwarePropertyDevices, change: .deviceList)
        // The devices of this recording; a default-device change restarts the tap anyway.
        var devices = Set<AudioObjectID>()
        for input in [false, true] {
            if let device = try? CoreAudioProperties.defaultDevice(input: input), device.isValid {
                devices.insert(device)
            }
        }
        for device in devices {
            register(kAudioDevicePropertyNominalSampleRate, on: device, change: .sampleRate)
        }
    }

    func invalidate() {
        for (object, address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, queue, block)
        }
        listeners.removeAll()
        continuation.finish()
    }

    private func register(
        _ selector: AudioObjectPropertySelector,
        on object: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
        change: Change
    ) {
        var address = CoreAudioProperties.address(selector)
        let continuation = self.continuation
        let knownDevices = self.knownDevices
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            if change == .deviceList {
                // Our own aggregate (re)creations also change the list: only a real device counts.
                let current = Self.externalDevices(CoreAudioProperties.deviceUIDs())
                let changed = knownDevices.uids.withLock { known in
                    defer { known = current }
                    return known != current
                }
                guard changed else { return }
            }
            continuation.yield(change)
        }
        let status = AudioObjectAddPropertyListenerBlock(object, &address, queue, block)
        if status == noErr {
            listeners.append((object, address, block))
        }
    }

    /// Device UIDs without Meety's own private aggregates.
    static func externalDevices(_ uids: Set<String>) -> Set<String> {
        uids.filter { !$0.hasPrefix(ProcessTapController.aggregateUIDPrefix) }
    }

    /// Human-readable default devices, for logs.
    static func snapshotDescription() -> String {
        let output =
            (try? CoreAudioProperties.defaultDevice(input: false)).map(CoreAudioProperties.deviceName) ?? "none"
        let input = (try? CoreAudioProperties.defaultDevice(input: true)).map(CoreAudioProperties.deviceName) ?? "none"
        return "output=\(output) input=\(input)"
    }
}
