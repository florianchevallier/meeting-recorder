import Cocoa
import CoreAudio
import AVFoundation

// MARK: - Log Detection Result
enum LogDetectionResult: CustomStringConvertible {
    case explicitStart  // Found recent START event without subsequent END
    case explicitEnd    // Found recent END event (more recent than any START)
    case noEvents       // No relevant events found in logs
    
    var description: String {
        switch self {
        case .explicitStart: return "START"
        case .explicitEnd: return "END" 
        case .noEvents: return "NO_EVENTS"
        }
    }
}

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
            Task {
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
            Logger.shared.log("🔍 [TEAMS] Teams not running")
            return false
        }
        
        // 2. Check Teams logs (reliable for explicit start/end events)
        let logResult = checkTeamsLogsWithState()
        
        // 3. Check for meeting windows (visual confirmation)
        let hasMeetingWindow = hasTeamsMeetingWindow()
        
        // 4. Check microphone usage (audio confirmation)  
        let micInUse = isMicrophoneActive()
        
        Logger.shared.log("🔍 [TEAMS] Detection results - Logs: \(logResult.description), Windows: \(hasMeetingWindow ? "✅" : "❌"), Mic: \(micInUse ? "✅" : "❌")")
        
        // Decision logic based on log state
        switch logResult {
        case .explicitEnd:
            // Logs explicitly show meeting ended - trust this over other indicators
            Logger.shared.log("🔍 [TEAMS] Explicit END in logs - meeting INACTIVE")
            return false
            
        case .explicitStart:
            // Logs explicitly show meeting started - meeting is active
            Logger.shared.log("🔍 [TEAMS] Explicit START in logs - meeting ACTIVE")
            return true
            
        case .noEvents:
            // No log events found - use stricter window + audio detection
            Logger.shared.log("🔍 [TEAMS] No log events found - using fallback detection")
            
            // For reliable auto-stop, require BOTH window AND microphone
            // This prevents false positives when Teams stays open but meeting ended
            if hasMeetingWindow && micInUse {
                Logger.shared.log("🔍 [TEAMS] Meeting window + mic active - meeting ACTIVE")
                return true
            } else if hasMeetingWindow {
                Logger.shared.log("🔍 [TEAMS] Meeting window found but no mic activity - meeting POSSIBLY ENDED")
                return false
            } else if micInUse {
                Logger.shared.log("🔍 [TEAMS] Mic active but no meeting window - meeting POSSIBLY ENDED")
                return false
            }
            
            Logger.shared.log("🔍 [TEAMS] No clear indicators - meeting INACTIVE")
            return false
        }
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
        guard let pid = app.processIdentifier as pid_t? else { 
            Logger.shared.log("🔍 [TEAMS] No PID for app")
            return false 
        }
        
        Logger.shared.log("🔍 [TEAMS] Checking windows for app: \(app.localizedName ?? "Unknown") (PID: \(pid))")
        
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        switch result {
        case .success:
            if let windows = windowsValue as? [AXUIElement] {
                Logger.shared.log("🔍 [TEAMS] Found \(windows.count) windows")
                
                // Check each window title for meeting indicators
                for (index, window) in windows.enumerated() {
                    if let title = getWindowTitle(window: window) {
                        let isMeeting = isMeetingWindow(title: title)
                        Logger.shared.log("🔍 [TEAMS] Window \(index + 1): \"\(title)\" -> Meeting: \(isMeeting)")
                        
                        if isMeeting {
                            Logger.shared.log("🔍 [TEAMS] 🎉 MEETING WINDOW DETECTED: \"\(title)\"")
                            return true
                        }
                    } else {
                        Logger.shared.log("🔍 [TEAMS] Window \(index + 1): (no title)")
                    }
                }
                
                Logger.shared.log("🔍 [TEAMS] No meeting windows found in \(windows.count) windows")
                return false
            } else {
                Logger.shared.log("🔍 [TEAMS] Got success but couldn't parse windows")
                return false
            }
        case .apiDisabled:
            Logger.shared.log("🔍 [TEAMS] ❌ Accessibility API is disabled")
            return false
        case .failure:
            Logger.shared.log("🔍 [TEAMS] ❌ Failed to access windows (general failure)")
            return false
        default:
            Logger.shared.log("🔍 [TEAMS] ❌ Error accessing windows: \(result.rawValue)")
            if result.rawValue == -25204 {
                Logger.shared.log("🔍 [TEAMS] 💡 Error -25204 usually means accessibility permission not granted")
            }
            return false
        }
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
        
        // Exclude patterns that indicate meeting has ended
        let excludePatterns = [
            "main window", "fenêtre principale",
            "chat", "teams home", "activity",
            "calendar", "calendrier", "files", "fichiers"
        ]
        
        let lowercaseTitle = title.lowercased()
        
        // First check if it's an excluded pattern (non-meeting window)
        for excludePattern in excludePatterns {
            if lowercaseTitle.contains(excludePattern.lowercased()) {
                return false
            }
        }
        
        // Then check if it matches meeting patterns
        return meetingKeywords.contains { keyword in
            lowercaseTitle.contains(keyword.lowercased())
        }
    }
    
    /// Check Teams logs for meeting status with explicit state detection
    private func checkTeamsLogsWithState() -> LogDetectionResult {
        // Implementation for checking Teams logs
        // This is a fallback method for when other detection fails
        
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
            
            // Look for recent meeting events (last 20 lines for better detection)
            let recentLines = Array(lines.suffix(20))
            
            // Parse recent events - find ALL events, don't break early
            var foundStartIndex = -1
            var foundEndIndex = -1
            
            for (index, line) in recentLines.enumerated() {
                // Check for meeting start indicators
                if line.contains("eventData: s::;m::1;a::1") {
                    Logger.shared.log("🔍 [TEAMS] Meeting START event found at line \(index)")
                    foundStartIndex = index
                }
                
                // Check for meeting end indicators
                if line.contains("eventData: s::;m::1;a::3") {
                    Logger.shared.log("🔍 [TEAMS] Meeting END event found at line \(index)")
                    foundEndIndex = index
                }
            }
            
            // Determine state based on which event was found last (higher index = more recent)
            if foundEndIndex >= 0 && foundStartIndex >= 0 {
                // Both events found - compare indices to see which is more recent
                let meetingIsActive = foundStartIndex > foundEndIndex
                Logger.shared.log("🔍 [TEAMS] Both events found - START at \(foundStartIndex), END at \(foundEndIndex) → Meeting \(meetingIsActive ? "ACTIVE" : "ENDED")")
                return meetingIsActive ? .explicitStart : .explicitEnd
            } else if foundEndIndex >= 0 {
                // Only END event found
                Logger.shared.log("🔍 [TEAMS] Only END event found - meeting ENDED")
                return .explicitEnd
            } else if foundStartIndex >= 0 {
                // Only START event found
                Logger.shared.log("🔍 [TEAMS] Only START event found - meeting ACTIVE")
                return .explicitStart
            }
        } catch {
            Logger.shared.log("❌ [TEAMS] Error reading Teams logs: \(error)")
        }
        
        return .noEvents
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
        
        let logResult = checkTeamsLogsWithState()
        let hasWindow = hasTeamsMeetingWindow()
        let micActive = isMicrophoneActive()
        
        switch logResult {
        case .explicitStart:
            return hasWindow ? "Logs + Window" : "Logs (START)"
        case .explicitEnd:
            return "Logs (END)"
        case .noEvents:
            if hasWindow && micActive { return "Window + Audio" }
            if hasWindow { return "Window only" }
            if micActive { return "Audio only" }
            return "No meeting detected"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let teamsMeetingStatusChanged = Notification.Name("teamsMeetingStatusChanged")
}