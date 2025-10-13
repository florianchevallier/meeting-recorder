import Cocoa
import CoreAudio
import AVFoundation

/// Abstraction layer around the system services used by `TeamsDetector`.
/// This makes the detector easier to test by allowing callers to inject
/// deterministic behaviours.
struct TeamsDetectionEnvironment {
    var isTeamsRunning: () -> Bool
    var readLogState: () -> LogDetectionResult
    var hasMeetingWindow: () -> Bool
    var isMicrophoneActive: () -> Bool
}

extension TeamsDetectionEnvironment {
    /// Default production environment backed by the real system APIs.
    static func live(
        logger: Logger = .shared,
        teamsBundleIdentifiers: [String]
    ) -> TeamsDetectionEnvironment {
        let live = LiveEnvironment(
            logger: logger,
            teamsBundleIdentifiers: teamsBundleIdentifiers
        )

        return TeamsDetectionEnvironment(
            isTeamsRunning: { live.isTeamsRunning() },
            readLogState: { live.checkTeamsLogsWithState() },
            hasMeetingWindow: { live.hasTeamsMeetingWindow() },
            isMicrophoneActive: { live.isMicrophoneActive() }
        )
    }
}

// MARK: - Live Implementation

private struct LiveEnvironment {
    private let logger: Logger
    private let teamsBundleIdentifiers: [String]

    init(logger: Logger, teamsBundleIdentifiers: [String]) {
        self.logger = logger
        self.teamsBundleIdentifiers = teamsBundleIdentifiers
    }

    func isTeamsRunning() -> Bool {
        for bundleId in teamsBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if !runningApps.isEmpty {
                return true
            }
        }
        return false
    }

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

    func hasTeamsMeetingWindow() -> Bool {
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
        guard let pid = app.processIdentifier as pid_t? else {
            logger.log("🔍 [TEAMS] No PID for app")
            return false
        }

        logger.log("🔍 [TEAMS] Checking windows for app: \(app.localizedName ?? "Unknown") (PID: \(pid))")

        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        switch result {
        case .success:
            if let windows = windowsValue as? [AXUIElement] {
                logger.log("🔍 [TEAMS] Found \(windows.count) windows")

                for (index, window) in windows.enumerated() {
                    if let title = getWindowTitle(window: window) {
                        let isMeeting = TeamsWindowClassifier.isMeetingWindow(title: title)
                        logger.log("🔍 [TEAMS] Window \(index + 1): \"\(title)\" -> Meeting: \(isMeeting)")

                        if isMeeting {
                            logger.log("🔍 [TEAMS] 🎉 MEETING WINDOW DETECTED: \"\(title)\"")
                            return true
                        }
                    } else {
                        logger.log("🔍 [TEAMS] Window \(index + 1): (no title)")
                    }
                }

                logger.log("🔍 [TEAMS] No meeting windows found in \(windows.count) windows")
                return false
            } else {
                logger.log("🔍 [TEAMS] Got success but couldn't parse windows")
                return false
            }
        case .apiDisabled:
            logger.log("🔍 [TEAMS] ❌ Accessibility API is disabled")
            return false
        case .failure:
            logger.log("🔍 [TEAMS] ❌ Failed to access windows (general failure)")
            return false
        default:
            logger.log("🔍 [TEAMS] ❌ Error accessing windows: \(result.rawValue)")
            if result.rawValue == -25204 {
                logger.log("🔍 [TEAMS] 💡 Error -25204 usually means accessibility permission not granted")
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

    func checkTeamsLogsWithState() -> LogDetectionResult {
        guard let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? else {
            return .noEvents
        }

        let logsPath = "\(homeDir)/Library/Application Support/Microsoft/Teams/logs.txt"

        guard FileManager.default.fileExists(atPath: logsPath) else {
            return .noEvents
        }

        do {
            let logsContent = try String(contentsOfFile: logsPath)
            let lines = logsContent.components(separatedBy: .newlines)
            let recentLines = Array(lines.suffix(20))

            var foundStartIndex = -1
            var foundEndIndex = -1

            for (index, line) in recentLines.enumerated() {
                if line.contains("eventData: s::;m::1;a::1") {
                    logger.log("🔍 [TEAMS] Meeting START event found")
                    foundStartIndex = index
                }

                if line.contains("eventData: s::;m::1;a::3") {
                    logger.log("🔍 [TEAMS] Meeting END event found")
                    foundEndIndex = index
                }
            }

            if foundEndIndex >= 0 && foundStartIndex >= 0 {
                let meetingIsActive = foundStartIndex > foundEndIndex
                logger.log("🔍 [TEAMS] Both events found - START at \(foundStartIndex), END at \(foundEndIndex) → Meeting \(meetingIsActive ? "ACTIVE" : "ENDED")")
                return meetingIsActive ? .explicitStart : .explicitEnd
            } else if foundEndIndex >= 0 {
                logger.log("🔍 [TEAMS] Only END event found - meeting ENDED")
                return .explicitEnd
            } else if foundStartIndex >= 0 {
                logger.log("🔍 [TEAMS] Only START event found - meeting ACTIVE")
                return .explicitStart
            }
        } catch {
            logger.log("❌ [TEAMS] Error reading Teams logs: \(error)")
        }

        return .noEvents
    }
}

// MARK: - Window Classification

struct TeamsWindowClassifier {
    static func isMeetingWindow(title: String) -> Bool {
        let meetingKeywords = [
            "meeting", "réunion", "call", "appel",
            "conference", "conférence", "teams meeting",
            "video call", "audio call", "conversation",
            "- Microsoft Teams"
        ]

        let excludePatterns = [
            "main window", "fenêtre principale",
            "chat", "teams home", "activity",
            "calendar", "calendrier", "files", "fichiers"
        ]

        let lowercaseTitle = title.lowercased()

        for excludePattern in excludePatterns {
            if lowercaseTitle.contains(excludePattern.lowercased()) {
                return false
            }
        }

        return meetingKeywords.contains { keyword in
            lowercaseTitle.contains(keyword.lowercased())
        }
    }
}
