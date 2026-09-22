import Foundation
import CoreAudio

/// Thin, typed wrappers around `AudioObjectGetPropertyData`. Every failure is a
/// `CaptureFailure.coreAudio` carrying the operation name for logs.
enum CoreAudioProperties {
    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    /// Reads a fixed-size trivial value (AudioObjectID, UInt32, Float64, ASBD…).
    static func value<T: BitwiseCopyable>(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        initial: T,
        operation: String
    ) throws(CaptureFailure) -> T {
        var address = self.address(selector, scope: scope)
        var size = UInt32(MemoryLayout<T>.size)
        var result = initial
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &result)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        return result
    }

    /// Reads a fixed-size value with a qualifier (e.g. pid → process object).
    static func value<T: BitwiseCopyable, Q: BitwiseCopyable>(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        qualifier: Q,
        initial: T,
        operation: String
    ) throws(CaptureFailure) -> T {
        var address = self.address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        var result = initial
        var qualifier = qualifier
        let status = withUnsafePointer(to: &qualifier) { qualifierPointer in
            AudioObjectGetPropertyData(
                objectID, &address,
                UInt32(MemoryLayout<Q>.size), qualifierPointer,
                &size, &result
            )
        }
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        return result
    }

    static func string(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        operation: String
    ) throws(CaptureFailure) -> String {
        var address = self.address(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        guard let value else { throw .coreAudio(status: kAudioHardwareUnknownPropertyError, operation: operation) }
        return value.takeRetainedValue() as String
    }

    /// Reads an array of trivial values (e.g. stream IDs).
    static func array<T: BitwiseCopyable>(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        operation: String
    ) throws(CaptureFailure) -> [T] {
        var address = self.address(selector, scope: scope)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        let count = Int(size) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { buffer.deallocate() }
        status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, buffer)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        return Array(UnsafeBufferPointer(start: buffer, count: Int(size) / MemoryLayout<T>.stride))
    }

    /// Channel count of each input stream of a device (kAudioDevicePropertyStreamConfiguration).
    static func inputStreamChannelCounts(
        _ deviceID: AudioObjectID,
        operation: String
    ) throws(CaptureFailure) -> [Int] {
        var address = self.address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        guard size > 0 else { return [] }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let listPointer = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, listPointer)
        guard status == noErr else { throw .coreAudio(status: status, operation: operation) }
        let list = UnsafeMutableAudioBufferListPointer(listPointer)
        return list.map { Int($0.mNumberChannels) }
    }

    // MARK: - Common lookups

    static func defaultDevice(input: Bool) throws(CaptureFailure) -> AudioObjectID {
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        return try value(
            AudioObjectID(kAudioObjectSystemObject), selector,
            initial: AudioObjectID(kAudioObjectUnknown),
            operation: input ? "DefaultInputDevice" : "DefaultOutputDevice"
        )
    }

    static func deviceUID(_ deviceID: AudioObjectID) throws(CaptureFailure) -> String {
        try string(deviceID, kAudioDevicePropertyDeviceUID, operation: "DeviceUID")
    }

    static func deviceName(_ deviceID: AudioObjectID) -> String {
        (try? string(deviceID, kAudioObjectPropertyName, operation: "DeviceName")) ?? "?"
    }

    static func nominalSampleRate(_ deviceID: AudioObjectID) throws(CaptureFailure) -> Double {
        try value(deviceID, kAudioDevicePropertyNominalSampleRate, initial: Double(0), operation: "NominalSampleRate")
    }

    /// Audio object of the current process (0 when the process has no audio client yet).
    static func ownProcessObject() -> AudioObjectID {
        let pid = ProcessInfo.processInfo.processIdentifier
        return
            (try? value(
                AudioObjectID(kAudioObjectSystemObject),
                kAudioHardwarePropertyTranslatePIDToProcessObject,
                qualifier: pid,
                initial: AudioObjectID(kAudioObjectUnknown),
                operation: "TranslatePIDToProcessObject"
            )) ?? AudioObjectID(kAudioObjectUnknown)
    }
}

extension AudioObjectID {
    var isValid: Bool { self != AudioObjectID(kAudioObjectUnknown) }
}
