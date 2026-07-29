import Cocoa
import CoreAudio
import AVFoundation

/// Production signal source backed by the real system APIs:
/// NSRunningApplication, Teams log files, the Accessibility API, and CoreAudio.
struct LiveTeamsSignalSource: TeamsSignalSource {

    static let defaultBundleIdentifiers = [
        "com.microsoft.teams2",         // New Teams
        "com.microsoft.teams",          // Old Teams
        "com.microsoft.Teams"           // Alternative identifier
    ]

    private let teamsBundleIdentifiers: [String]

    init(teamsBundleIdentifiers: [String] = defaultBundleIdentifiers) {
        self.teamsBundleIdentifiers = teamsBundleIdentifiers
    }

    // MARK: - Teams Running

    func isTeamsRunning() -> Bool {
        for bundleId in teamsBundleIdentifiers {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty {
                return true
            }
        }
        return false
    }

    // MARK: - Microphone Active (CoreAudio)

    func isMicrophoneActive() -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr && deviceID != kAudioDeviceUnknown else {
            return false
        }

        propertyAddress.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var isRunning: UInt32 = 0
        propertySize = UInt32(MemoryLayout<UInt32>.size)

        let runningStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &isRunning
        )

        return runningStatus == noErr && isRunning != 0
    }

    // MARK: - Meeting Window (Accessibility API)

    func hasMeetingWindow() -> Bool {
        for bundleId in teamsBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            for app in runningApps {
                if checkAppForMeetingWindows(app: app) {
                    return true
                }
            }
        }
        return false
    }

    private func checkAppForMeetingWindows(app: NSRunningApplication) -> Bool {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        switch result {
        case .success:
            guard let windows = windowsValue as? [AXUIElement] else {
                Logger.shared.debug("AX success but window list unreadable", component: "TEAMS")
                return false
            }

            for window in windows {
                if let title = getWindowTitle(window: window),
                   TeamsWindowClassifier.isMeetingWindow(title: title) {
                    Logger.shared.info("Meeting window detected: \"\(title)\"", component: "TEAMS")
                    return true
                }
            }
            return false

        case .apiDisabled:
            Logger.shared.debug("Accessibility API is disabled", component: "TEAMS")
            return false

        default:
            Logger.shared.debug("AX windows access failed: \(result.rawValue)", component: "TEAMS")
            if result.rawValue == -25204 {
                Logger.shared.debug("Error -25204: accessibility permission not granted", component: "TEAMS")
            }
            return false
        }
    }

    private func getWindowTitle(window: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        guard result == .success, let title = titleValue as? String else {
            return nil
        }
        return title
    }

    // MARK: - Log Parsing (old Teams log location, kept for parity)

    func readLogState() -> LogDetectionResult {
        let logsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Microsoft/Teams/logs.txt")
            .path

        guard FileManager.default.fileExists(atPath: logsPath) else {
            return .noEvents
        }

        do {
            let logsContent = try String(contentsOfFile: logsPath, encoding: .utf8)
            let lines = logsContent.components(separatedBy: .newlines)
            let recentLines = Array(lines.suffix(20))

            var foundStartIndex = -1
            var foundEndIndex = -1

            for (index, line) in recentLines.enumerated() {
                if line.contains("eventData: s::;m::1;a::1") {
                    foundStartIndex = index
                }
                if line.contains("eventData: s::;m::1;a::3") {
                    foundEndIndex = index
                }
            }

            if foundEndIndex >= 0 && foundStartIndex >= 0 {
                return foundStartIndex > foundEndIndex ? .explicitStart : .explicitEnd
            } else if foundEndIndex >= 0 {
                return .explicitEnd
            } else if foundStartIndex >= 0 {
                return .explicitStart
            }
        } catch {
            Logger.shared.error("Error reading Teams logs: \(error.localizedDescription)", component: "TEAMS")
        }

        return .noEvents
    }
}
