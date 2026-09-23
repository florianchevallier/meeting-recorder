import Testing
import Foundation
@testable import MeetingRecorder

/// Scriptable probes: the monitor's logic without TCC.
final class FakeProbes: PermissionProbes, @unchecked Sendable {
    var microphone: PermissionStatus = .notDetermined
    var accessibilityTrusted = false
    var microphoneRequestAnswer = true
    var calendar: PermissionStatus = .notDetermined
    var calendarRequestAnswer = true
    /// Mimics `EKEventStore.authorizationStatus` keeping the launch value after a grant.
    var calendarStatusIsStale = false
    private(set) var calendarRequests = 0

    func microphoneStatus() -> PermissionStatus { microphone }
    func requestMicrophone() async -> Bool {
        microphone = microphoneRequestAnswer ? .granted : .denied
        return microphoneRequestAnswer
    }
    func isAccessibilityTrusted() -> Bool { accessibilityTrusted }
    func promptAccessibility() {}
    func calendarStatus() -> PermissionStatus { calendar }
    func requestCalendar() async -> Bool {
        calendarRequests += 1
        if !calendarStatusIsStale { calendar = calendarRequestAnswer ? .granted : .denied }
        return calendarRequestAnswer
    }
}

struct FakeSystemAudioProbe: SystemAudioAccessProbing {
    let outcome: SystemAudioPermissionProbe.Outcome
    func run() async -> SystemAudioPermissionProbe.Outcome { outcome }
}

@MainActor
@Suite("PermissionMonitor")
struct PermissionMonitorTests {

    private func makeDefaults() -> UserDefaults {
        ScratchDefaults.make()
    }

    @Test("Microphone status maps straight from the probe")
    func microphoneMapping() {
        let probes = FakeProbes()
        probes.microphone = .denied
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: makeDefaults())
        #expect(monitor.microphone == .denied)
        probes.microphone = .granted
        monitor.refresh()
        #expect(monitor.microphone == .granted)
    }

    @Test("System audio is unknown until first use, then persists the outcome")
    func systemAudioLifecycle() {
        let defaults = makeDefaults()
        let monitor = PermissionMonitor(probes: FakeProbes(), systemAudioProbe: nil, defaults: defaults)
        #expect(monitor.systemAudio == .unknownUntilFirstUse)

        monitor.recordSystemAudioOutcome(.denied)
        #expect(monitor.systemAudio == .denied)

        // Simulated relaunch on the same defaults
        let relaunched = PermissionMonitor(probes: FakeProbes(), systemAudioProbe: nil, defaults: defaults)
        #expect(relaunched.systemAudio == .denied)

        relaunched.recordSystemAudioOutcome(.granted)
        #expect(relaunched.systemAudio == .granted)
        relaunched.recordSystemAudioOutcome(.indeterminate)
        #expect(relaunched.systemAudio == .granted)
    }

    @Test("requestSystemAudio applies the probe outcome")
    func systemAudioProbeOutcome() async {
        let granted = PermissionMonitor(
            probes: FakeProbes(), systemAudioProbe: FakeSystemAudioProbe(outcome: .audioReceived),
            defaults: makeDefaults()
        )
        await granted.requestSystemAudio()
        #expect(granted.systemAudio == .granted)

        let unknown = PermissionMonitor(
            probes: FakeProbes(), systemAudioProbe: FakeSystemAudioProbe(outcome: .failed(.noOutputDevice)),
            defaults: makeDefaults()
        )
        await unknown.requestSystemAudio()
        #expect(unknown.systemAudio == .unknownUntilFirstUse)
    }

    @Test("Accessibility is notDetermined until prompted, denied after a prompt without trust, granted when trusted")
    func accessibilityStates() {
        let probes = FakeProbes()
        let defaults = makeDefaults()
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: defaults)
        #expect(monitor.accessibility == .notDetermined)

        defaults.set(true, for: .accessibilityPrompted)
        monitor.refresh()
        #expect(monitor.accessibility == .denied)

        probes.accessibilityTrusted = true
        monitor.refresh()
        #expect(monitor.accessibility == .granted)
    }

    @Test("requestMicrophone only prompts when undetermined")
    func microphoneRequest() async {
        let probes = FakeProbes()
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: makeDefaults())
        await monitor.requestMicrophone()
        #expect(monitor.microphone == .granted)
    }

    @Test("Derived flags: recording allowed, onboarding satisfied, blockers")
    func derived() {
        let probes = FakeProbes()
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: makeDefaults())
        #expect(!monitor.isRecordingAllowed)
        #expect(monitor.blockers == [.microphone])

        probes.microphone = .granted
        monitor.refresh()
        #expect(monitor.isRecordingAllowed)  // system audio unknown does not block
        #expect(monitor.blockers.isEmpty)
        #expect(!monitor.isOnboardingSatisfied)

        monitor.recordSystemAudioOutcome(.denied)
        #expect(!monitor.isRecordingAllowed)
        #expect(monitor.blockers == [.systemAudio])

        probes.accessibilityTrusted = true
        monitor.refresh()
        #expect(monitor.isOnboardingSatisfied)
    }

    @Test("Calendar maps from the probe, prompts only when undetermined, and never blocks recording or onboarding")
    func calendar() async {
        let probes = FakeProbes()
        probes.microphone = .granted
        probes.accessibilityTrusted = true
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: makeDefaults())
        #expect(monitor.calendar == .notDetermined)
        #expect(monitor.isRecordingAllowed)
        #expect(monitor.isOnboardingSatisfied)

        await monitor.requestCalendar()
        #expect(monitor.calendar == .granted)
        #expect(monitor.status(for: .calendar) == .granted)

        await monitor.requestCalendar()
        #expect(probes.calendarRequests == 1)
    }

    @Test("A granted request counts even when the system status stays stale until relaunch")
    func calendarStaleStatus() async {
        let probes = FakeProbes()
        probes.calendarStatusIsStale = true
        let monitor = PermissionMonitor(probes: probes, systemAudioProbe: nil, defaults: makeDefaults())

        await monitor.requestCalendar()
        #expect(monitor.calendar == .granted)
        monitor.refresh()  // app activation: the probe still says notDetermined
        #expect(monitor.calendar == .granted)

        probes.calendar = .denied  // revoked in System Settings
        monitor.refresh()
        #expect(monitor.calendar == .denied)
    }
}
