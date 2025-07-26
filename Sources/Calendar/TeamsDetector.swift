import Cocoa
import CoreAudio
import AVFoundation

@MainActor
class TeamsDetector: ObservableObject {
    @Published var isTeamsMeetingActive = false
    @Published var lastDetectionTime: Date?
    
    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = 2.0 // Check every 2 seconds
    
    // Teams bundle identifiers for different versions
    private let teamsBundleIdentifiers = [
        "com.microsoft.teams2",         // New Teams
        "com.microsoft.teams",          // Old Teams
        "com.microsoft.Teams"           // Alternative identifier
    ]
    
    func startMonitoring() {
        Logger.shared.log("🔍 [TEAMS] Starting Teams meeting detection...")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkTeamsMeetingStatus()
            }
        }
    }
    
    func stopMonitoring() {
        Logger.shared.log("🔍 [TEAMS] Stopping Teams meeting detection")
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func checkTeamsMeetingStatus() async {
        let meetingDetected = detectActiveTeamsMeeting()
        
        if meetingDetected != isTeamsMeetingActive {
            isTeamsMeetingActive = meetingDetected
            lastDetectionTime = Date()
            
            Logger.shared.log("🔍 [TEAMS] Meeting status changed: \(meetingDetected ? "ACTIVE" : "INACTIVE")")
            
            // Notify other components about the status change
            NotificationCenter.default.post(
                name: .teamsMeetingStatusChanged,
                object: nil,
                userInfo: ["isActive": meetingDetected]
            )
        }
    }
    
    // MARK: - Detection Methods
    
    /// Main detection method combining multiple approaches
    private func detectActiveTeamsMeeting() -> Bool {
        // 1. Check if Teams is running
        guard isTeamsRunning() else {
            return false
        }
        
        // 2. Check microphone usage (global indicator)
        let micInUse = isMicrophoneActive()
        
        // 3. Check for meeting windows (if Teams is running and mic is active)
        if micInUse {
            let hasMeetingWindow = hasTeamsMeetingWindow()
            Logger.shared.log("🔍 [TEAMS] Teams running: ✅, Mic active: ✅, Meeting window: \(hasMeetingWindow ? "✅" : "❌")")
            return hasMeetingWindow
        }
        
        // 4. Fallback: Check Teams logs if available
        let logDetection = checkTeamsLogs()
        Logger.shared.log("🔍 [TEAMS] Teams running: ✅, Mic active: ❌, Log detection: \(logDetection ? "✅" : "❌")")
        return logDetection
    }
    
    /// Check if Microsoft Teams is currently running
    private func isTeamsRunning() -> Bool {
        for bundleId in teamsBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if !runningApps.isEmpty {
                return true
            }
        }
        return false
    }
    
    /// Check if microphone is currently active (system-wide)
    private func isMicrophoneActive() -> Bool {
        // Check if any audio input device is currently active
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
        
        // Check if the default input device is running
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
    
    /// Check for Teams meeting windows using Accessibility API
    private func hasTeamsMeetingWindow() -> Bool {
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
    
    /// Check specific app for meeting-related windows
    private func checkAppForMeetingWindows(app: NSRunningApplication) -> Bool {
        guard let pid = app.processIdentifier as pid_t? else { return false }
        
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return false
        }
        
        // Check each window title for meeting indicators
        for window in windows {
            if let title = getWindowTitle(window: window) {
                if isMeetingWindow(title: title) {
                    Logger.shared.log("🔍 [TEAMS] Meeting window detected: \"\(title)\"")
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Get window title from AXUIElement
    private func getWindowTitle(window: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        
        guard result == .success, let title = titleValue as? String else {
            return nil
        }
        
        return title
    }
    
    /// Check if window title indicates a meeting
    private func isMeetingWindow(title: String) -> Bool {
        let meetingKeywords = [
            "meeting", "réunion", "call", "appel",
            "conference", "conférence", "teams meeting",
            "video call", "audio call", "conversation",
            "- Microsoft Teams" // Meeting windows often end with this
        ]
        
        let lowercaseTitle = title.lowercased()
        
        return meetingKeywords.contains { keyword in
            lowercaseTitle.contains(keyword.lowercased())
        }
    }
    
    /// Check Teams logs for meeting status (fallback method)
    private func checkTeamsLogs() -> Bool {
        // Implementation for checking Teams logs
        // This is a fallback method for when other detection fails
        
        guard let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? else {
            return false
        }
        
        let logsPath = "\(homeDir)/Library/Application Support/Microsoft/Teams/logs.txt"
        
        guard FileManager.default.fileExists(atPath: logsPath) else {
            return false
        }
        
        do {
            let logsContent = try String(contentsOfFile: logsPath)
            let lines = logsContent.components(separatedBy: .newlines)
            
            // Look for recent meeting events (last 10 lines)
            let recentLines = Array(lines.suffix(10))
            
            for line in recentLines {
                // Check for meeting start indicators
                if line.contains("eventData: s::;m::1;a::1") {
                    Logger.shared.log("🔍 [TEAMS] Meeting detected in logs: START event")
                    return true
                }
                
                // Check for meeting end indicators
                if line.contains("eventData: s::;m::1;a::3") {
                    Logger.shared.log("🔍 [TEAMS] Meeting detected in logs: END event")
                    return false
                }
            }
        } catch {
            Logger.shared.log("❌ [TEAMS] Error reading Teams logs: \(error)")
        }
        
        return false
    }
    
    // MARK: - Public Interface
    
    /// Manual check for Teams meeting status
    func checkNow() async -> Bool {
        await checkTeamsMeetingStatus()
        return isTeamsMeetingActive
    }
    
    /// Get current detection status with details
    func getDetectionStatus() -> (isActive: Bool, lastCheck: Date?, method: String) {
        let method = determineLastDetectionMethod()
        return (isTeamsMeetingActive, lastDetectionTime, method)
    }
    
    private func determineLastDetectionMethod() -> String {
        if !isTeamsRunning() { return "Teams not running" }
        if isMicrophoneActive() && hasTeamsMeetingWindow() { return "Window + Audio" }
        if isMicrophoneActive() { return "Audio only" }
        if checkTeamsLogs() { return "Logs" }
        return "No meeting detected"
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let teamsMeetingStatusChanged = Notification.Name("teamsMeetingStatusChanged")
}