# MeetingRecorder (Meety) - AI Agent Guidelines

**README for AI Agents** - This file provides guidance when working with this codebase, based on deep code analysis.

## Project Identity

- **Public Name**: MeetingRecorder
- **Brand Name**: **Meety** (user-facing, see [Logger.swift:12](Sources/Utils/Logger.swift#L12))
- **Product**: macOS status bar app for automatic Teams meeting recording
- **Output**: System audio + microphone → M4A files

## Critical Technical Facts (From Real Code)

### Platform Requirements

```swift
// Package.swift:10 - ACTUAL minimum version
platforms: [.macOS(.v14)]  // NOT 12.3, it's 14.0!
```

- **Minimum macOS**: 14.0 (not 12.3 as documented elsewhere)
- **macOS 15+ bonus**: `UnifiedScreenCapture` with direct .mov→M4A
- **macOS < 15**: Legacy path (`SystemAudioCapture` + `MicrophoneCapture` → `AudioMixer`)

### Build Commands - CRITICAL ⚠️

```bash
# ✅ CORRECT - The ONLY way to run this app
swift build
./.build/debug/MeetingRecorder

# ❌ NEVER DO THIS - Will fail silently
swift run
```

**Why**: Status bar apps need direct executable invocation for proper NSApp activation policy (`.accessory`).

### Log Files Location (Actual Code)

```swift
// Logger.swift:12-13 - Dev vs prod detection
let appName = bundleId.contains(".dev") ? "MeetyDev" : "Meety"
// Output: ~/Documents/Meety_debug.log OR ~/Documents/MeetyDev_debug.log
```

**Not** `MeetingRecorder_debug.log` - check bundle ID for actual filename!

## Architecture Deep Dive

### Central Coordinator Pattern

**StatusBarManager** ([StatusBarManager.swift:6](Sources/StatusBar/StatusBarManager.swift#L6)) is the **single source of truth**:

```swift
@MainActor class StatusBarManager: ObservableObject {
    // Owns ALL audio components
    private let micRecorder = SimpleMicrophoneRecorder()  // Line 16
    private var systemAudioCapture: (any NSObjectProtocol)?  // Line 17
    private var unifiedCapture: (any NSObjectProtocol)?  // Line 20

    // Publishes state to UI
    @Published var isRecording = false  // Line 9
    @Published var recordingDuration: TimeInterval = 0  // Line 10
    @Published var isTeamsMeetingDetected = false  // Line 12
}
```

**Critical**: NEVER instantiate audio classes directly. StatusBarManager coordinates everything.

### Dual Audio Pipeline (Version-Dependent)

#### macOS 15+ Path ([StatusBarManager.swift:188-216](Sources/StatusBar/StatusBarManager.swift#L188))

```swift
if #available(macOS 15.0, *) {
    let unified = UnifiedScreenCapture()
    try await unified.startDirectRecording()  // Direct to .mov
    unifiedCapture = unified
}
```

**Features**:
- `SCRecordingOutput` directly writes .mov file
- Built-in microphone capture via `configuration.captureMicrophone = true` ([UnifiedScreenCapture.swift:85](Sources/Audio/UnifiedScreenCapture.swift#L85))
- Needs conversion: `.mov` → `.m4a` via `convertMOVToM4A()` ([UnifiedScreenCapture.swift:390](Sources/Audio/UnifiedScreenCapture.swift#L390))

#### macOS < 15 Path ([StatusBarManager.swift:218-232](Sources/StatusBar/StatusBarManager.swift#L218))

```swift
try micRecorder.startRecording()  // AVAudioEngine
if #available(macOS 13.0, *) {
    let systemCapture = SystemAudioCapture()
    try await systemCapture.startRecording()  // ScreenCaptureKit
}
```

**Features**:
- Separate `.wav` files per source
- Combined via `AudioMixer.mixAudioFiles()` ([AudioMixer.swift:6](Sources/Audio/AudioMixer.swift#L6))
- Auto-cleanup of temp files ([AudioMixer.swift:58-65](Sources/Audio/AudioMixer.swift#L58))

### Teams Detection System

**TeamsDetector** ([TeamsDetector.swift:19](Sources/Calendar/TeamsDetector.swift#L19)) uses multi-signal approach:

```swift
// Three detection signals (TeamsDetector.swift:90-102)
let logResult = environment.readLogState()          // Parse Teams logs
let hasMeetingWindow = environment.hasMeetingWindow()  // Accessibility API
let micInUse = environment.isMicrophoneActive()     // System audio check
```

**Decision logic** in `TeamsMeetingDecider` ([TeamsMeetingDecider.swift](Sources/Calendar/TeamsMeetingDecider.swift)):
- **Explicit START** in logs → meeting active
- **Explicit END** in logs → meeting inactive
- **Fallback**: Window + mic → active, otherwise → inactive

**Communication**: NotificationCenter broadcast → StatusBarManager listener ([StatusBarManager.swift:44-55](Sources/StatusBar/StatusBarManager.swift#L44))

## Code Style Rules (From Actual Code)

### Logging Standard

```swift
// ✅ CORRECT - Every log has [COMPONENT] prefix
Logger.shared.log("🎬 [RECORDING] Started recording at \(timestamp)")
Logger.shared.log("🔍 [TEAMS] Meeting status changed: ACTIVE")
Logger.shared.log("❌ [AUDIO_MIXER] Export failed: \(error)")

// ❌ NEVER - No print() anywhere in codebase
print("Something happened")  // Will be ignored
```

**Emoji prefixes used**:
- `🎬` Recording lifecycle
- `🔍` Teams detection
- `🎤` Microphone
- `🔊` System audio
- `❌` Errors
- `✅` Success
- `⚠️` Warnings
- `🚨` Critical errors

### Localization Pattern

```swift
// Localization.swift defines ALL strings
extension L10n {
    static let statusRecording = "status.recording".localized  // Line 36
    static func errorRecordingFailed(_ error: String) -> String {
        return "error.recording_failed".localized(error)  // Line 85
    }
}

// Usage in code
errorMessage = L10n.errorRecordingFailed(error.localizedDescription)
```

**Rule**: NEVER hardcode user-facing strings. Always add to `L10n` + both `.lproj` files.

### Concurrency Patterns

```swift
// StatusBarManager is @MainActor (Line 5)
@MainActor class StatusBarManager: ObservableObject {

    func startRecording() {  // Line 163
        Task {  // Async work
            do {
                try await unified.startDirectRecording()
                await MainActor.run {  // Line 234 - UI updates
                    isRecording = true
                    updateStatusBarIcon()
                }
            } catch { /* ... */ }
        }
    }
}
```

**Pattern**: Method on `@MainActor` → `Task {}` for async work → `await MainActor.run {}` for UI updates

## Audio Configuration (DO NOT MODIFY)

### ScreenCaptureKit Constants ([SystemAudioCapture.swift:35-36](Sources/Audio/SystemAudioCapture.swift#L35))

```swift
configuration.sampleRate = 48000      // 48kHz audio
configuration.channelCount = 2        // Stereo
configuration.excludesCurrentProcessAudio = true  // Prevent feedback
```

### AVAudioEngine Constants ([MicrophoneCapture.swift:47](Sources/Audio/MicrophoneCapture.swift#L47))

```swift
inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat)
```

**Why 1024**: Low-latency real-time mixing requirement. Changing this causes audio drift.

## Permission Management (Real Implementation)

### Accessibility Check ([PermissionManager.swift:141-174](Sources/Permissions/PermissionManager.swift#L141))

```swift
private func testWindowAccess() -> Bool {
    let finderApp = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.finder"
    ).first

    let appElement = AXUIElementCreateApplication(pid)
    var windowsValue: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
        appElement, kAXWindowsAttribute as CFString, &windowsValue
    )
    return result == .success  // Can we see windows?
}
```

**Why**: TeamsDetector needs Accessibility to read window titles. This is a **real functional test**, not just checking status.

### Screen Recording Check ([PermissionManager.swift:61-78](Sources/Permissions/PermissionManager.swift#L61))

```swift
let content = try await SCShareableContent.excludingDesktopWindows(
    false, onScreenWindowsOnly: true
)
let hasPermission = !content.displays.isEmpty
```

**macOS Sequoia 2024+**: Only way to reliably check screen recording permission.

## Common Modification Patterns

### Adding a New Audio Source

1. **Create capture class** in `Sources/Audio/`
2. **Add to StatusBarManager** as stored property (Lines 16-20)
3. **Integrate in dual pipeline**:
   - macOS 15+: Add to `UnifiedScreenCapture` config
   - macOS < 15: Add to `AudioMixer.mixAudioFiles()` parameters
4. **Update `recordingDuration` calculation** (Lines 344-350)

### Adding a New Permission

1. **Add `@Published` property** to `PermissionManager` (Lines 10-13)
2. **Implement `check` method** (follow pattern Lines 36-41, 61-78)
3. **Implement `request` method** (follow pattern Lines 28-34, 44-59)
4. **Add to `checkAllPermissions()`** (Line 20)
5. **Update `allPermissionsGranted` computed property** (Line 188)
6. **Add to OnboardingView**

### Modifying Teams Detection Logic

**DO**:
- Modify `TeamsMeetingDecider.decide()` logic ([TeamsMeetingDecider.swift](Sources/Calendar/TeamsMeetingDecider.swift))
- Adjust detection thresholds in `TeamsDetectionEnvironment` ([TeamsDetectionEnvironment.swift](Sources/Calendar/TeamsDetectionEnvironment.swift))

**DON'T**:
- Break Accessibility API calls (will fail silently if permission revoked)
- Remove fallback detection paths (logs + window + mic)

## Anti-Patterns Found in Code Comments

### Commented Out Code to Avoid

```swift
// SystemAudioCapture.swift:212-217 - DO NOT USE
// Using bufferListNoCopy to avoid distortions from CMSampleBufferCopyPCMDataIntoAudioBufferList
guard let audioBuffer = AVAudioPCMBuffer(
    pcmFormat: format,
    bufferListNoCopy: audioBufferList.unsafePointer  // Critical for quality
) else { return }
```

**Why**: `CMSampleBufferCopyPCMDataIntoAudioBufferList` causes audio distortion. Use `bufferListNoCopy`.

### Error Recovery Pattern ([UnifiedScreenCapture.swift:499-519](Sources/Audio/UnifiedScreenCapture.swift#L499))

```swift
func stream(_ stream: SCStream, didStopWithError error: Error) {
    let isRecoverable = isErrorRecoverable(error)  // Line 510

    if isRecoverable && retryCount < maxRetryCount {
        attemptRecovery()  // Line 745 - Auto-restart
    } else {
        handleCriticalError(error)  // Line 804 - Notify user
    }
}
```

**Recoverable errors**: -3821 (system stopped stream), -3812 (invalid param), -3801 (config error)

## Testing Strategy (Actual Implementation)

### Unit Tests Exist

- `Tests/MeetingRecorderTests/TeamsDetectorTests.swift`
- `Tests/MeetingRecorderTests/TeamsMeetingDeciderTests.swift`
- `Tests/MeetingRecorderTests/TeamsWindowClassifierTests.swift`

**Run**: `swift test`

### Manual Testing Required

1. **Build**: `swift build`
2. **Run**: `./.build/debug/MeetingRecorder`
3. **Monitor**: `tail -f ~/Documents/Meety_debug.log`
4. **Join Teams meeting** (real one, not mock)
5. **Verify auto-recording** starts/stops
6. **Check output**: `ls -la ~/Documents/meeting_*.m4a`

### Permission Reset for Testing

```bash
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app
tccutil reset SystemPolicyDesktopFolder com.meetingrecorder.app
```

**Note**: Accessibility permission requires System Preferences manual toggle.

## Critical File Reference

| Component | File | Lines | Key Responsibility |
|-----------|------|-------|-------------------|
| **Entry point** | MeetingRecorderApp.swift | 25-42 | AppDelegate setup, accessory app policy |
| **Main controller** | StatusBarManager.swift | 163-251 | Recording lifecycle, Teams integration |
| **macOS 15+ capture** | UnifiedScreenCapture.swift | 47-143 | Direct .mov recording with recovery |
| **Legacy system audio** | SystemAudioCapture.swift | 21-111 | ScreenCaptureKit (macOS 13+) |
| **Microphone** | MicrophoneCapture.swift | 20-67 | AVAudioEngine tap |
| **Audio mixing** | AudioMixer.swift | 6-72 | Combine sources → M4A export |
| **Teams logic** | TeamsMeetingDecider.swift | - | Multi-signal decision tree |
| **Teams detector** | TeamsDetector.swift | 70-134 | Timer-based monitoring |
| **Permissions** | PermissionManager.swift | 20-194 | All 4 permissions with real tests |
| **Logging** | Logger.swift | 8-16 | Dev/prod log file selection |
| **Localization** | Localization.swift | 29-110 | All user-facing strings |

## Debug Workflow

### Common Issues

**"Recording not starting"**:
1. Check: `~/Documents/Meety_debug.log` for permission errors
2. Look for: `❌ [RECORDING] Missing microphone permission`
3. Fix: Run `PermissionManager.shared.requestAllPermissions()`

**"Teams not detected"**:
1. Check: `🔍 [TEAMS]` logs every 2 seconds (when verbose)
2. Verify: Accessibility permission granted
3. Test: `TeamsDetector.checkNow()` for manual trigger

**"Audio quality issues"**:
1. Check: Sample rate consistency (must be 48kHz)
2. Verify: `AudioMixer` receives valid URLs
3. Look for: `❌ [AUDIO_MIXER]` errors in logs

### Log Interpretation

```
[2025-01-27 10:30:45.123] 🔍 [TEAMS] Detection results - Logs: START, Windows: ✅, Mic: ✅
[2025-01-27 10:30:45.456] 🔍 [TEAMS] Explicit START in logs - meeting ACTIVE
[2025-01-27 10:30:45.789] 🎬 [AUTO] Starting automatic recording for Teams meeting
[2025-01-27 10:30:46.012] 🚀 [RECORDING] Using unified capture (macOS 15+)
[2025-01-27 10:30:47.234] ✅ [UNIFIED_CAPTURE] Unified recording started
```

**Reading tips**:
- Timestamps show exact sequence
- Emoji = component type
- `[COMPONENT]` = source file area
- `ACTIVE/INACTIVE` = state transitions

## Advanced Topics

### Health Monitoring ([UnifiedScreenCapture.swift:301-383](Sources/Audio/UnifiedScreenCapture.swift#L301))

```swift
private var healthCheckTimer: Timer?
private let healthCheckInterval: TimeInterval = 5.0  // Every 5s

private func performHealthCheck() {
    let timeSinceLastSample = now.timeIntervalSince(lastSampleTime)
    if timeSinceLastSample > 10.0 {
        Logger.shared.log("🩺 [HEALTH_MONITOR] ⚠️ No samples for \(timeSinceLastSample)s")
        checkStreamHealth()  // Detailed system check
    }
}
```

**Checks**: Microphone connected, displays available, memory usage, thermal state

### MOV to M4A Conversion ([UnifiedScreenCapture.swift:390-485](Sources/Audio/UnifiedScreenCapture.swift#L390))

```swift
// Wait for file stability (15s max)
while Date() < deadline {
    if currentSize > 0 && currentSize == lastSize {
        stableCount += 1
        if stableCount >= 2 { break }  // Stable for 1 second
    }
}

// Then convert
let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
```

**Why stability check**: `SCRecordingOutput` writes asynchronously, must wait for completion.

## Documentation Hierarchy

1. **AGENTS.md** (this file) - AI agent reference with code links
2. **CLAUDE.md** - Human developer documentation
3. **README.md** - Project overview
4. **Code comments** - Implementation details

**When in doubt**: Read the actual implementation, not the docs!

---

*Last code analysis: 2025-01-27*
*Based on: Package.swift (macOS 14), StatusBarManager.swift (dual pipeline), UnifiedScreenCapture.swift (recovery)*
*Compatible with: Claude Code, GitHub Copilot, Cursor, all AI assistants*
