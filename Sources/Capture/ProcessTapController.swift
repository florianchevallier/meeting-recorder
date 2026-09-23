import Foundation
import AVFoundation
import CoreAudio
import os

/// One capture session: a global process tap + a private aggregate device
/// (default output as clock master, default microphone as drift-compensated
/// sub-device, the tap as input) + an IOProc on a dedicated serial queue.
///
/// Not thread-safe: owned and driven by `CaptureEngine` (or the permission
/// probe). The IO block only touches the values captured in `start(handler:)`.
final class ProcessTapController {

    struct Configuration: Sendable {
        var includeMicrophone = true
        var excludeOwnProcess = true
        /// nil = every process (global tap); otherwise a stereo mixdown of these objects.
        var processObjects: [AudioObjectID]? = nil
    }

    /// One HAL stream as delivered in the IOProc's input buffer list.
    /// `@unchecked`: `AVAudioFormat` is immutable and safe to read from any thread.
    struct StreamFormat: @unchecked Sendable {
        let bufferIndex: Int
        let format: AVAudioFormat
        let source: CaptureStreamLayout.Source
    }

    typealias IOHandler =
        @Sendable (
            _ inputData: UnsafePointer<AudioBufferList>,
            _ inputTime: UnsafePointer<AudioTimeStamp>,
            _ now: UnsafePointer<AudioTimeStamp>,
            _ formats: [StreamFormat]
        ) -> Void

    let configuration: Configuration
    private(set) var layout: CaptureStreamLayout?
    private(set) var streamFormats: [StreamFormat] = []
    private(set) var outputDeviceName = "?"
    private(set) var microphoneDeviceName: String?

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "com.meetingrecorder.meety.capture.io", qos: .userInteractive)

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Lifecycle

    /// `prepare()` + `run(handler:)` in one call.
    func start(handler: @escaping IOHandler) throws(CaptureFailure) {
        try prepare()
        try run(handler: handler)
    }

    /// Builds tap + aggregate device and infers the stream layout (`streamFormats`
    /// is valid afterwards). No audio flows yet.
    func prepare() throws(CaptureFailure) {
        guard !aggregateID.isValid else { throw .alreadyRecording }

        let outputDevice = try CoreAudioProperties.defaultDevice(input: false)
        guard outputDevice.isValid else { throw .noOutputDevice }
        let outputUID = try CoreAudioProperties.deviceUID(outputDevice)
        outputDeviceName = CoreAudioProperties.deviceName(outputDevice)

        var microphoneUID: String?
        var microphoneChannels: [Int] = []
        if configuration.includeMicrophone {
            let inputDevice = try CoreAudioProperties.defaultDevice(input: true)
            if inputDevice.isValid {
                microphoneUID = try CoreAudioProperties.deviceUID(inputDevice)
                microphoneChannels = try CoreAudioProperties.inputStreamChannelCounts(
                    inputDevice, operation: "MicStreamConfiguration")
                microphoneDeviceName = CoreAudioProperties.deviceName(inputDevice)
            } else {
                Log.capture.warning("No default input device — recording system audio only")
            }
        }

        do {
            try createTap()
            try createAggregate(outputUID: outputUID, microphoneUID: microphoneUID)
            try resolveFormats(microphoneChannels: microphoneChannels)
        } catch {
            teardown()
            throw error
        }
    }

    /// Starts IO. The first start after install triggers the "System Audio
    /// Recording" (and microphone) TCC prompts and blocks until the user answers.
    func run(handler: @escaping IOHandler) throws(CaptureFailure) {
        guard aggregateID.isValid, procID == nil else { throw .alreadyRecording }
        do {
            try startIO(handler: handler)
        } catch {
            teardown()
            throw error
        }
    }

    func stop() {
        teardown()
    }

    // MARK: - Build steps

    private func createTap() throws(CaptureFailure) {
        let description: CATapDescription
        if let processes = configuration.processObjects {
            description = CATapDescription(stereoMixdownOfProcesses: processes)
        } else {
            var excluded: [AudioObjectID] = []
            if configuration.excludeOwnProcess {
                let own = CoreAudioProperties.ownProcessObject()
                if own.isValid { excluded.append(own) }
            }
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        }
        description.uuid = UUID()
        description.name = "Meety"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var newTap = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &newTap)
        guard status == noErr, newTap.isValid else {
            throw status == noErr
                ? .tapUnavailable : .coreAudio(status: status, operation: "AudioHardwareCreateProcessTap")
        }
        tapID = newTap
        tapUUID = description.uuid
    }

    private var tapUUID = UUID()

    /// Our private aggregates come and go with every tap (re)build; the device
    /// observer ignores them (otherwise each restart would trigger the next one).
    static let aggregateUIDPrefix = "com.meetingrecorder.meety.aggregate."

    private func createAggregate(outputUID: String, microphoneUID: String?) throws(CaptureFailure) {
        var subDevices: [[String: Any]] = [[kAudioSubDeviceUIDKey: outputUID]]
        if let microphoneUID, microphoneUID != outputUID {
            subDevices.append([
                kAudioSubDeviceUIDKey: microphoneUID,
                kAudioSubDeviceDriftCompensationKey: true,
            ])
        }
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Meety Capture",
            kAudioAggregateDeviceUIDKey: Self.aggregateUIDPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceSubDeviceListKey: subDevices,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]
        var newAggregate = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newAggregate)
        guard status == noErr, newAggregate.isValid else {
            throw .coreAudio(status: status, operation: "AudioHardwareCreateAggregateDevice")
        }
        aggregateID = newAggregate
    }

    private func resolveFormats(microphoneChannels: [Int]) throws(CaptureFailure) {
        let sampleRate = try CoreAudioProperties.nominalSampleRate(aggregateID)
        let bufferChannels = try CoreAudioProperties.inputStreamChannelCounts(
            aggregateID, operation: "AggregateStreamConfiguration")
        let tapASBD = try CoreAudioProperties.value(
            tapID, kAudioTapPropertyFormat,
            initial: AudioStreamBasicDescription(), operation: "TapFormat"
        )
        let tapChannels = Int(tapASBD.mChannelsPerFrame)

        var inferred = CaptureStreamLayout.infer(
            bufferChannelCounts: bufferChannels,
            microphoneStreamChannelCounts: microphoneChannels,
            tapChannelCount: tapChannels,
            sampleRate: sampleRate
        )
        if inferred == nil {
            // Unknown shape: assume the last buffer with the tap's channel count is the tap.
            Log.capture.warning(
                "Unexpected aggregate stream shape \(bufferChannels, privacy: .public) (mic \(microphoneChannels, privacy: .public), tap \(tapChannels)) — using fallback mapping"
            )
            let tapIndex = bufferChannels.lastIndex(of: tapChannels) ?? (bufferChannels.count - 1)
            let streams = bufferChannels.enumerated().map { index, channels in
                CaptureStreamLayout.Stream(
                    bufferIndex: index, channels: channels, source: index == tapIndex ? .systemTap : .microphone)
            }
            inferred = CaptureStreamLayout(streams: streams, sampleRate: sampleRate)
        }
        guard let layout = inferred, !layout.tapStreams.isEmpty else {
            throw .coreAudio(status: kAudioHardwareBadStreamError, operation: "ResolveLayout")
        }
        self.layout = layout
        streamFormats = layout.streams.compactMap { stream in
            CaptureFormat.halStreamFormat(sampleRate: sampleRate, channels: AVAudioChannelCount(stream.channels))
                .map { StreamFormat(bufferIndex: stream.bufferIndex, format: $0, source: stream.source) }
        }
        Log.capture.info(
            "Aggregate ready: out=\(self.outputDeviceName, privacy: .public) mic=\(self.microphoneDeviceName ?? "none", privacy: .public) rate=\(sampleRate, privacy: .public) buffers=\(bufferChannels, privacy: .public) tapChannels=\(tapChannels)"
        )
    }

    private func startIO(handler: @escaping IOHandler) throws(CaptureFailure) {
        var newProc: AudioDeviceIOProcID?
        let formats = streamFormats
        let status = AudioDeviceCreateIOProcIDWithBlock(&newProc, aggregateID, ioQueue) {
            now, inputData, inputTime, _, _ in
            handler(inputData, inputTime, now, formats)
        }
        guard status == noErr, let newProc else {
            throw .coreAudio(status: status, operation: "AudioDeviceCreateIOProcIDWithBlock")
        }
        procID = newProc
        let startStatus = AudioDeviceStart(aggregateID, newProc)
        guard startStatus == noErr else {
            throw .coreAudio(status: startStatus, operation: "AudioDeviceStart")
        }
    }

    private func teardown() {
        if aggregateID.isValid {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID.isValid {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit {
        teardown()
    }
}
