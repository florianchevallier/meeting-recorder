import os
import Foundation
import CoreAudio

/// "Is a Teams process using the microphone?"
///
/// Trigger: the device-level `kAudioDevicePropertyDeviceIsRunningSomewhere`
/// listener (reliable on macOS 26) plus the process-object list. Truth: a read
/// of `kAudioProcessPropertyIsRunningInput` for every Teams process object, so
/// Meety's own capture never counts.
@MainActor
final class TeamsMicrophoneObserver {
    private let onChange: @MainActor (Bool) -> Void
    private var teamsPIDs: Set<pid_t> = []
    private var isActive = false

    private var systemListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var deviceListener: (AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)?
    private var recheckTask: Task<Void, Never>?

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard systemListeners.isEmpty else { return }
        addSystemListener(kAudioHardwarePropertyProcessObjectList)
        addSystemListener(kAudioHardwarePropertyDefaultInputDevice)
        attachDefaultInputDevice()
    }

    func stop() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        for (address, block) in systemListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(system, &address, .main, block)
        }
        systemListeners.removeAll()
        detachDevice()
        recheckTask?.cancel()
        recheckTask = nil
    }

    func setTeamsPIDs(_ pids: Set<pid_t>) {
        teamsPIDs = pids
        evaluate()
    }

    // MARK: - Listeners

    private func addSystemListener(_ selector: AudioObjectPropertySelector) {
        var address = CoreAudioProperties.address(selector)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.triggered(selector: selector) }
        }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block) == noErr
        {
            systemListeners.append((address, block))
        }
    }

    private func attachDefaultInputDevice() {
        detachDevice()
        guard let device = try? CoreAudioProperties.defaultDevice(input: true), device.isValid else { return }
        var address = CoreAudioProperties.address(kAudioDevicePropertyDeviceIsRunningSomewhere)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.triggered(selector: kAudioDevicePropertyDeviceIsRunningSomewhere) }
        }
        if AudioObjectAddPropertyListenerBlock(device, &address, .main, block) == noErr {
            deviceListener = (device, address, block)
        }
    }

    private func detachDevice() {
        if let (device, address, block) = deviceListener {
            var address = address
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, block)
        }
        deviceListener = nil
    }

    private func triggered(selector: AudioObjectPropertySelector) {
        if selector == kAudioHardwarePropertyDefaultInputDevice {
            attachDefaultInputDevice()
        }
        evaluate()
        // The per-process running flag lags the device-level trigger slightly.
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.TeamsDetection.microphoneRecheckDelay))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    // MARK: - Evaluation

    private func evaluate() {
        let active = !teamsPIDs.isEmpty && Self.isAnyProcessRunningInput(pids: teamsPIDs)
        guard active != isActive else { return }
        isActive = active
        Log.teams.debug("Teams microphone active: \(active)")
        onChange(active)
    }

    nonisolated static func isAnyProcessRunningInput(pids: Set<pid_t>) -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard
            let objects: [AudioObjectID] = try? CoreAudioProperties.array(
                system, kAudioHardwarePropertyProcessObjectList, operation: "ProcessObjectList"
            )
        else { return false }

        for object in objects {
            guard
                let pid: pid_t = try? CoreAudioProperties.value(
                    object, kAudioProcessPropertyPID, initial: pid_t(0), operation: "ProcessPID"
                ), pids.contains(pid)
            else { continue }
            let running: UInt32 =
                (try? CoreAudioProperties.value(
                    object, kAudioProcessPropertyIsRunningInput, initial: UInt32(0), operation: "ProcessIsRunningInput"
                )) ?? 0
            if running != 0 { return true }
        }
        return false
    }
}
