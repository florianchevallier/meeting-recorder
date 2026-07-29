import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import MachO

/// Deep diagnostics logged when the system stops the stream (error -3821).
/// Log-only: helps diagnose sleeps, display changes, competing capture apps.
enum CaptureDiagnostics {

    static func runDeepDiagnostics(
        outputURL: URL?,
        lastStreamDimensions: (width: Int, height: Int)?
    ) async {
        Logger.shared.info("=== DIAGNOSTIC -3821: stream stopped by system ===", component: "DIAGNOSTICS")
        checkSystemState()
        await checkPermissions()
        checkSystemResources(outputURL: outputURL)
        await checkDisplayConfiguration(lastStreamDimensions: lastStreamDimensions)
        checkCompetingApps()
    }

    // MARK: - System State

    private static func checkSystemState() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &memoryInfo) { memoryInfoPtr in
            withUnsafeMutablePointer(to: &count) { countPtr in
                task_info(
                    task_self_trap(),
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    UnsafeMutablePointer<integer_t>(OpaquePointer(memoryInfoPtr)),
                    countPtr
                )
            }
        }

        if result == KERN_SUCCESS {
            let memoryMB = memoryInfo.resident_size / (1024 * 1024)
            Logger.shared.info("App memory usage: \(memoryMB) MB", component: "DIAGNOSTICS")
        }

        let processInfo = ProcessInfo.processInfo
        Logger.shared.info("System uptime: \(processInfo.systemUptime)s", component: "DIAGNOSTICS")
        Logger.shared.info("Thermal state: \(processInfo.thermalState.rawValue)", component: "DIAGNOSTICS")
    }

    // MARK: - Permissions

    private static func checkPermissions() async {
        do {
            let content = try await SCShareableContent.current
            Logger.shared.info("Available displays: \(content.displays.count)", component: "DIAGNOSTICS")
            Logger.shared.info("Available applications: \(content.applications.count)", component: "DIAGNOSTICS")
            Logger.shared.info("Available windows: \(content.windows.count)", component: "DIAGNOSTICS")
        } catch {
            Logger.shared.error("Shareable content check failed: \(error.localizedDescription)", component: "DIAGNOSTICS")
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        Logger.shared.info("Microphone permission: \(micStatus.rawValue)", component: "DIAGNOSTICS")

        if let defaultMic = AVCaptureDevice.default(for: .audio) {
            Logger.shared.info("Default microphone: \(defaultMic.localizedName), connected: \(defaultMic.isConnected)", component: "DIAGNOSTICS")
        } else {
            Logger.shared.warning("No default microphone available", component: "DIAGNOSTICS")
        }
    }

    // MARK: - Resources

    private static func checkSystemResources(outputURL: URL?) {
        if let outputURL {
            do {
                let resourceValues = try outputURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let availableCapacity = resourceValues.volumeAvailableCapacity {
                    let availableGB = availableCapacity / (1024 * 1024 * 1024)
                    Logger.shared.info("Available disk space: \(availableGB) GB", component: "DIAGNOSTICS")
                }
            } catch {
                Logger.shared.error("Disk space check failed: \(error.localizedDescription)", component: "DIAGNOSTICS")
            }
        }

        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS {
            Logger.shared.info("CPU cores: \(numCpus)", component: "DIAGNOSTICS")
        }
    }

    // MARK: - Display Configuration

    private static func checkDisplayConfiguration(lastStreamDimensions: (width: Int, height: Int)?) async {
        do {
            let content = try await SCShareableContent.current
            for (index, display) in content.displays.enumerated() {
                Logger.shared.info("Display \(index): \(display.width)x\(display.height)", component: "DIAGNOSTICS")
            }

            if let last = lastStreamDimensions, let currentDisplay = content.displays.first {
                if currentDisplay.width != last.width || currentDisplay.height != last.height {
                    Logger.shared.warning(
                        "DISPLAY RESOLUTION CHANGED: \(last.width)x\(last.height) → \(currentDisplay.width)x\(currentDisplay.height)",
                        component: "DIAGNOSTICS"
                    )
                }
            }
        } catch {
            Logger.shared.error("Display configuration check failed: \(error.localizedDescription)", component: "DIAGNOSTICS")
        }
    }

    // MARK: - Competing Apps

    private static func checkCompetingApps() {
        let screenCapturingApps = [
            "com.apple.QuickTimePlayerX",
            "com.apple.screencapture",
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.skype.skype",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.apple.Safari"
        ]

        var competitorsFound: [String] = []
        var videoConferencingApps: [String] = []

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier else { continue }
            if screenCapturingApps.contains(bundleId) {
                competitorsFound.append(app.localizedName ?? bundleId)
            }
            if bundleId.contains("zoom") || bundleId.contains("teams") || bundleId.contains("meet") {
                videoConferencingApps.append(app.localizedName ?? bundleId)
            }
        }

        if !competitorsFound.isEmpty {
            Logger.shared.info("Potential competitors: \(competitorsFound.joined(separator: ", "))", component: "DIAGNOSTICS")
        }
        if !videoConferencingApps.isEmpty {
            Logger.shared.warning("Video conferencing apps: \(videoConferencingApps.joined(separator: ", "))", component: "DIAGNOSTICS")
        }
        if competitorsFound.isEmpty && videoConferencingApps.isEmpty {
            Logger.shared.info("No known competitors detected", component: "DIAGNOSTICS")
        }
    }
}
