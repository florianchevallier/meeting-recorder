# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ IMPORTANT RULES FOR CLAUDE

**DO NOT CREATE NEW MARKDOWN FILES**

- ❌ **NEVER** create files like `SETUP_GUIDE.md`, `DEPLOYMENT_GUIDE.md`, `TROUBLESHOOTING.md`, etc.
- ❌ **NEVER** create "helpful documentation files" that pollute the repository
- ✅ **ALWAYS** put documentation directly in `CLAUDE.md` (this file)
- ✅ **ONLY** create files when explicitly requested by the user

**DO NOT ADD CO-AUTHORS TO GIT COMMITS**

- ❌ **NEVER** add `Co-authored-by: Cursor <cursoragent@cursor.com>` to commit messages
- ❌ **NEVER** add `Co-authored-by: Claude <noreply@anthropic.com>` to commit messages
- ❌ **NEVER** add any AI assistant as co-author in commits
- ✅ **ALWAYS** keep commits attributed to the human developer only

**Why?** The project has a single human maintainer (Florian Chevallier). AI assistants are tools, not contributors. Adding co-authors pollutes the contributor list on GitHub and misrepresents project ownership.

**NEVER COMMIT ON BEHALF OF THE USER**

- ❌ **NEVER** run `git commit` commands without explicit user instruction
- ❌ **NEVER** automatically commit changes, even if they seem "ready"
- ❌ **NEVER** commit after making changes, even with a good commit message
- ✅ **ALWAYS** stage changes with `git add` and show status
- ✅ **ALWAYS** let the user decide when and how to commit
- ✅ **ONLY** commit if the user explicitly asks "commit this" or "make a commit"

**Why?** The user wants full control over when commits happen. Claude should prepare changes and show what's ready to commit, but the final `git commit` command must come from explicit user instruction, not automatic assistant behavior.

**Why?** The project already has comprehensive documentation in:
- `CLAUDE.md` - Complete technical reference for AI assistants
- `README.md` - User-facing project overview
- `AGENTS.md` - AI agent guidelines
- Existing specific guides (e.g., `INSTALLATION_GUIDE.md`, `DEPLOYMENT.md`)

**If you need to document something new**: Add a section to `CLAUDE.md`, don't create a new file.

---

# MeetingRecorder (Meety) - macOS Meeting Recording Application

## Project Overview
Native macOS status bar application that automatically records meetings by capturing system audio and microphone, with automatic Teams meeting detection. The application runs entirely from the status bar and produces high-quality M4A files.

**Brand Name**: **Meety** (user-facing, see [Logger.swift:12](Sources/Utils/Logger.swift#L12))
**Current Status: MVP Complete** ✅ - All core features are production-ready.

## Essential Development Commands

### Build & Run
```bash
# Debug build and run (primary method)
swift build
./.build/debug/MeetingRecorder

# NEVER use `swift run` - always use the direct executable
# This ensures proper status bar behavior and permission handling

# Release build
swift build -c release

# Create app bundle for distribution  
./debug_app.sh
# Output: .build/MeetingRecorder.app

# Run tests
swift test
```

### Debugging & Troubleshooting
```bash
# View real-time application logs (uses macOS Unified Logging System)
# Open Console.app and search for "Meety" or subsystem "com.meetingrecorder.app"
open -a Console

# Or use command line to stream logs
log stream --predicate 'subsystem == "com.meetingrecorder.app"' --level debug

# Show last 100 log entries
log show --predicate 'subsystem == "com.meetingrecorder.app"' --last 100

# Reset system permissions for testing
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app
tccutil reset SystemPolicyDesktopFolder com.meetingrecorder.app  # Documents access

# Check generated recording files
ls -la ~/Documents/meeting_*.m4a
```

## Code Signing & Distribution

### Automated GitHub Actions Workflow ✅ CONFIGURED

The project uses **GitHub Actions** for automated build, signing, and notarization:

```
git push tag → GitHub Actions → Signed & Notarized DMG → GitHub Release
```

**What happens automatically**:
1. ✅ Build universal binary (arm64 + x86_64)
2. ✅ Sign with Developer ID Application certificate
3. ✅ Create and sign DMG
4. ✅ Submit to Apple for notarization
5. ✅ Staple notarization ticket
6. ✅ Create GitHub Release with DMG attached

**To create a release**:
```bash
./scripts/release.sh 0.1.17
```

See [`RELEASE_WORKFLOW.md`](RELEASE_WORKFLOW.md) for complete guide.

### Apple Certificate Types

The project requires proper code signing for distribution. There are **three different certificate types** with distinct purposes:

| Certificate Type | Purpose | Usage | Current Status |
|-----------------|---------|-------|----------------|
| **Apple Development** | Local development & testing | Debug builds on your devices | Not needed for CI |
| **Apple Distribution** | App Store submission | Submit via App Store Connect | Not used (direct distribution) |
| **Developer ID Application** | Direct distribution | DMG, website downloads, notarization | ✅ **Used in GitHub Actions** |

**IMPORTANT**:
- GitHub Actions uses **Developer ID Application** certificate stored as secret
- Local builds use ad-hoc signing (for testing only)
- Production releases are **fully automated** via GitHub Actions

### Setting Up GitHub Actions Secrets (One-Time Setup)

**7 secrets required** in GitHub repository settings:

| Secret | Value | How to Get |
|--------|-------|------------|
| `DEVELOPER_ID_CERTIFICATE` | Base64-encoded P12 | Export from Keychain → `base64 -i Certificates.p12` |
| `CERTIFICATE_PASSWORD` | P12 password | Set when exporting from Keychain |
| `KEYCHAIN_PASSWORD` | Random password | Generate: `openssl rand -base64 32` |
| `SIGNING_IDENTITY` | Full identity string | `Developer ID Application: in-Tact (42BB3NJ35Q)` |
| `APPLE_ID` | Apple Developer email | Your account email |
| `APPLE_TEAM_ID` | Team identifier | `42BB3NJ35Q` |
| `APPLE_APP_PASSWORD` | App-specific password | Generate at appleid.apple.com |

**Step-by-step setup**:

#### 1. Create Developer ID Certificate

```bash
# Open Keychain Access
open "/Applications/Utilities/Keychain Access.app"

# Menu: Keychain Access → Certificate Assistant → Request Certificate from CA
# - Email: your Apple Developer email
# - Common Name: in-Tact Developer ID
# - Save to disk
```

Then:
1. Go to https://developer.apple.com/account/resources/certificates/add
2. Select **Developer ID Application**
3. Upload your `.certSigningRequest` file
4. Download the `.cer` certificate
5. Double-click to install in Keychain

#### 2. Export Certificate as P12

```bash
# In Keychain Access:
# 1. Select "login" → "My Certificates"
# 2. Find "Developer ID Application: in-Tact (42BB3NJ35Q)"
# 3. Right-click → Export
# 4. Format: Personal Information Exchange (.p12)
# 5. Set a strong password (save for CERTIFICATE_PASSWORD)

# Convert to base64
base64 -i Certificates.p12 -o certificate_base64.txt

# Copy the output (one line)
cat certificate_base64.txt | pbcopy

# IMPORTANT: Delete these files after setup!
rm Certificates.p12 certificate_base64.txt
```

#### 3. Generate App-Specific Password

```bash
# 1. Go to https://appleid.apple.com/account/manage
# 2. Sign in with your Apple ID
# 3. Security → App-Specific Passwords
# 4. Generate password (name: "GitHub Actions Notarization")
# 5. Copy the password (format: xxxx-xxxx-xxxx-xxxx)
```

#### 4. Add Secrets to GitHub

```bash
# Go to: https://github.com/florianchevallier/meeting-recorder/settings/secrets/actions
# Click "New repository secret" for each:

DEVELOPER_ID_CERTIFICATE → paste base64 certificate
CERTIFICATE_PASSWORD → paste P12 password
KEYCHAIN_PASSWORD → generate with: openssl rand -base64 32
SIGNING_IDENTITY → Developer ID Application: in-Tact (42BB3NJ35Q)
APPLE_ID → your email
APPLE_TEAM_ID → 42BB3NJ35Q
APPLE_APP_PASSWORD → paste app-specific password
```

**Verification**:
```bash
# All 7 secrets should appear in:
# GitHub → Settings → Secrets and variables → Actions
```

### Local Development (No Signing Required)

For local testing, use ad-hoc signing:

```bash
# Build and run locally
swift build
./.build/debug/MeetingRecorder

# Create local app bundle for testing
./debug_app.sh
```

**Note**: Local builds are **NOT notarized** and will show security warnings on other Macs. Use GitHub Actions for production releases.

### Manual Signing (Advanced)

If you need to sign locally (not recommended - use GitHub Actions instead):

```bash
# Sign and package locally
./sign_and_package.sh

# Notarize manually
./notarize_and_staple.sh

# Verify
spctl --assess --type install --verbose dist/Meety-Installer.dmg
```

See [`sign_and_package.sh`](sign_and_package.sh) and [`notarize_and_staple.sh`](notarize_and_staple.sh) for implementation details.

## Architecture Overview

The application follows a modular MVVM architecture with clear separation of concerns:

### Core Audio Pipeline (Sources/Audio/)
- **AudioMixer.swift**: Real-time audio mixing and M4A export using AVFoundation
- **SystemAudioCapture.swift**: ScreenCaptureKit system audio capture (macOS 13+)
- **MicrophoneCapture.swift**: AVAudioEngine microphone recording
- **UnifiedScreenCapture.swift**: macOS 15+ unified capture with direct .mov recording

**Audio Flow**: System audio (ScreenCaptureKit) + Microphone (AVAudioEngine) → Real-time mixing (AudioMixer) → M4A output (48kHz AAC stereo)

### Status Bar System (Sources/StatusBar/)
- **StatusBarManager.swift**: Main application controller, coordinates all subsystems, handles Teams detection events
- **StatusBarMenu.swift**: SwiftUI-based popover interface with recording controls

**Key Integration**: StatusBarManager acts as the central coordinator between audio capture, Teams detection, permission management, and user interface.

### Teams Detection (Sources/Calendar/)
- **TeamsDetector.swift**: Automatic Teams meeting detection using Accessibility API
- Monitors running processes and window titles for Teams meetings
- Sends notifications via NotificationCenter when meeting status changes
- StatusBarManager listens for these events to trigger auto-recording

### Permission Management (Sources/Permissions/)
- **PermissionManager.swift**: Centralized handling of all macOS permissions
- Manages: Microphone, Screen Recording, Documents access, Accessibility API
- Provides unified status checking and permission request workflows

### Onboarding Flow (Sources/Onboarding/)
- **OnboardingManager.swift**: Controls first-launch flow and permission requests
- **OnboardingView.swift**: SwiftUI interface for permission setup
- **OnboardingViewModel.swift**: Business logic for onboarding state management

## Critical Technical Details

### macOS Version Compatibility
- **macOS 14.0+**: **ACTUAL minimum** (see [Package.swift:10](Package.swift#L10) - `platforms: [.macOS(.v14)]`)
- **macOS 13.0+**: ScreenCaptureKit system audio capture available via legacy path
- **macOS 15.0+**: UnifiedScreenCapture with direct .mov recording and built-in recovery

**Important**: Despite ScreenCaptureKit being available since macOS 12.3, this project requires macOS 14.0+ as declared in Package.swift.

### Audio Configuration
```swift
// ScreenCaptureKit configuration (SystemAudioCapture)
config.capturesAudio = true
config.sampleRate = 48000
config.channelCount = 2
config.excludesCurrentProcessAudio = true

// AVAudioEngine configuration (MicrophoneCapture)  
bufferSize = 1024 // Low latency for real-time mixing
format = 48kHz stereo PCM
```

### Recording Architecture Pattern
The application uses a dual-path recording approach coordinated by StatusBarManager:

#### macOS 15+ Path ([StatusBarManager.swift:188-216](Sources/StatusBar/StatusBarManager.swift#L188))
```swift
if #available(macOS 15.0, *) {
    let unified = UnifiedScreenCapture()
    try await unified.startDirectRecording()  // Direct to .mov with SCRecordingOutput
    unifiedCapture = unified
}
```
- Uses `SCRecordingOutput` for direct file writing
- Built-in microphone capture via `configuration.captureMicrophone = true`
- Automatic error recovery for errors -3821, -3812, -3801 ([UnifiedScreenCapture.swift:499-519](Sources/Audio/UnifiedScreenCapture.swift#L499))
- Health monitoring every 5 seconds ([UnifiedScreenCapture.swift:301-383](Sources/Audio/UnifiedScreenCapture.swift#L301))
- Converts `.mov` → `.m4a` after recording ([UnifiedScreenCapture.swift:390](Sources/Audio/UnifiedScreenCapture.swift#L390))

#### macOS < 15 Path ([StatusBarManager.swift:218-232](Sources/StatusBar/StatusBarManager.swift#L218))
```swift
try micRecorder.startRecording()  // SimpleMicrophoneRecorder (AVAudioEngine)
if #available(macOS 13.0, *) {
    let systemCapture = SystemAudioCapture()  // ScreenCaptureKit
    try await systemCapture.startRecording()
}
```
- Separate `.wav` files for each source
- Combined via `AudioMixer.mixAudioFiles()` ([AudioMixer.swift:6](Sources/Audio/AudioMixer.swift#L6))
- Automatic cleanup of temporary files ([AudioMixer.swift:58-65](Sources/Audio/AudioMixer.swift#L58))

**StatusBarManager** acts as the central coordinator, transparently switching between approaches.

### Teams Detection Integration

**TeamsDetector** ([TeamsDetector.swift:19](Sources/Calendar/TeamsDetector.swift#L19)) uses a multi-signal approach:

```swift
// Three detection signals (TeamsDetector.swift:90-102)
let logResult = environment.readLogState()          // Parse Teams log files
let hasMeetingWindow = environment.hasMeetingWindow()  // Accessibility API
let micInUse = environment.isMicrophoneActive()     // System audio monitoring
```

**Decision Logic** ([TeamsMeetingDecider.swift](Sources/Calendar/TeamsMeetingDecider.swift)):
- **Explicit START** in logs → meeting active
- **Explicit END** in logs → meeting inactive
- **Fallback**: Window + mic active → meeting active, otherwise → inactive

**Communication** ([StatusBarManager.swift:44-55](Sources/StatusBar/StatusBarManager.swift#L44)):
```swift
NotificationCenter.default.addObserver(
    forName: .teamsMeetingStatusChanged,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let isActive = notification.userInfo?["isActive"] as? Bool else { return }
    self?.handleTeamsMeetingStatusChange(isActive: isActive)
}
```

Timer-based monitoring every 2 seconds ([TeamsDetector.swift:24](Sources/Calendar/TeamsDetector.swift#L24))

## Permission Requirements

The application requires four system permissions, all managed by PermissionManager:

1. **Microphone** (AVFoundation): Voice recording
2. **Screen Recording** (ScreenCaptureKit): System audio capture  
3. **Documents Folder**: File storage for recordings
4. **Accessibility API**: Teams window monitoring for auto-detection

**Permission Flow**: OnboardingManager → PermissionManager → User prompts → StatusBarManager validation

## Key Code Locations

| Function | File:Line | Purpose | Implementation Detail |
|----------|-----------|---------|----------------------|
| `startRecording()` | [StatusBarManager.swift:163](Sources/StatusBar/StatusBarManager.swift#L163) | Main recording workflow coordinator | Version-aware pipeline selection |
| `startDirectRecording()` | [UnifiedScreenCapture.swift:47](Sources/Audio/UnifiedScreenCapture.swift#L47) | macOS 15+ unified capture | Direct .mov with recovery |
| `mixAudioFiles()` | [AudioMixer.swift:6](Sources/Audio/AudioMixer.swift#L6) | Legacy audio mixing and M4A export | Combines mic + system audio |
| `handleTeamsMeetingStatusChange()` | [StatusBarManager.swift:58](Sources/StatusBar/StatusBarManager.swift#L58) | Auto-recording decision logic | Triggered by NotificationCenter |
| `detectActiveTeamsMeeting()` | [TeamsDetector.swift:90](Sources/Calendar/TeamsDetector.swift#L90) | Multi-signal Teams detection | Logs + window + mic analysis |
| `checkAllPermissions()` | [PermissionManager.swift:20](Sources/Permissions/PermissionManager.swift#L20) | Complete permission validation | Real functional tests |
| `testWindowAccess()` | [PermissionManager.swift:141](Sources/Permissions/PermissionManager.swift#L141) | Accessibility permission test | Uses Finder AXUIElement |
| `convertMOVToM4A()` | [UnifiedScreenCapture.swift:390](Sources/Audio/UnifiedScreenCapture.swift#L390) | Post-recording conversion | Waits for file stability |

## Application Lifecycle

1. **MeetingRecorderApp.swift**: Entry point, sets up AppDelegate
2. **AppDelegate**: Creates StatusBarManager, handles onboarding check
3. **StatusBarManager**: Initializes all subsystems (audio, Teams detection, permissions)
4. **OnboardingManager**: Manages first-launch permission flow if needed
5. **Runtime**: Status bar interface handles user interactions and auto-recording

## Logging and Debugging

The application uses Apple's **Unified Logging System (os_log)** via `Logger.shared` for professional, system-integrated logging.

**Key Features**:
- ✅ **Smart filtering**: Debug logs automatically filtered in production builds
- ✅ **No visible files**: Logs managed by macOS, accessible via Console.app
- ✅ **Performance optimized**: Apple's native logging framework
- ✅ **Privacy-first**: Follows macOS logging standards

**Accessing Logs**:

1. **Console.app** (GUI):
   ```bash
   open -a Console
   # Search for: "Meety" or subsystem "com.meetingrecorder.app"
   ```

2. **Command Line** (real-time):
   ```bash
   # Stream logs as they happen
   log stream --predicate 'subsystem == "com.meetingrecorder.app"' --level debug

   # Show last 100 entries
   log show --predicate 'subsystem == "com.meetingrecorder.app"' --last 100

   # Filter by component
   log show --predicate 'subsystem == "com.meetingrecorder.app" AND category == "general"'
   ```

**Logging Levels**:
- `debug()` - Development details (filtered in production)
- `info()` - General information (always persisted)
- `warning()` - Potential issues (always persisted)
- `error()` - Critical errors (always persisted)

**Structured Logging Convention**:
- Emoji prefixes: `🎬` Recording, `🔍` Teams, `🎤` Mic, `🔊` System, `❌` Error, `✅` Success, `⚠️` Warning
- Component tags: `[RECORDING]`, `[TEAMS]`, `[AUDIO_MIXER]`, `[UNIFIED_CAPTURE]`, `[HEALTH_MONITOR]`

**Example Log Output** (in Console.app):
```
🔍 [TEAMS] Detection results - Logs: START, Windows: ✅, Mic: ✅
🎬 [AUTO] Starting automatic recording for Teams meeting
🚀 [RECORDING] Using unified capture (macOS 15+)
✅ [UNIFIED_CAPTURE] Unified recording started
```

## Testing Strategy

### Unit Tests ([Tests/MeetingRecorderTests/](Tests/))
- `TeamsDetectorTests.swift` - Teams detection logic with mock environments
- `TeamsMeetingDeciderTests.swift` - Multi-signal decision tree validation
- `TeamsWindowClassifierTests.swift` - Window title pattern matching
- **Run**: `swift test`

### Manual Testing Workflow
1. **Build**: `swift build`
2. **Run**: `./.build/debug/MeetingRecorder` (NEVER use `swift run`)
3. **Monitor Logs**: `log stream --predicate 'subsystem == "com.meetingrecorder.app"' --level debug`
4. **Join Real Teams Meeting**: Test auto-detection and recording
5. **Verify Output**: `ls -la ~/Documents/meeting_*.m4a`
6. **Check Audio Quality**: Play M4A file with QuickTime/VLC

### Permission Testing
```bash
# Reset all permissions for clean testing
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app
tccutil reset SystemPolicyDesktopFolder com.meetingrecorder.app

# Note: Accessibility requires manual toggle in System Preferences
```

### Debugging Common Issues

**Recording not starting**:
- Check: `❌ [RECORDING] Missing microphone permission` in logs
- Verify: All permissions granted via PermissionManager

**Teams not detected**:
- Check: `🔍 [TEAMS]` logs (every 2 seconds when verbose)
- Verify: Accessibility permission granted
- Test: Manual trigger with `TeamsDetector.checkNow()`

**Audio quality issues**:
- Check: Sample rate consistency (must be 48kHz)
- Look for: `❌ [AUDIO_MIXER]` errors during mixing
- Verify: Both source files exist before mixing

## Common Development Patterns

### Concurrency
- **@MainActor Classes**: StatusBarManager, TeamsDetector for UI thread safety
- **Async/Await Pattern**: Method on @MainActor → `Task {}` → `await MainActor.run {}` for UI updates
- **Example** ([StatusBarManager.swift:163-241](Sources/StatusBar/StatusBarManager.swift#L163)):
```swift
func startRecording() {  // On @MainActor
    Task {  // Async work off main thread
        try await unified.startDirectRecording()
        await MainActor.run {  // UI updates back on main
            isRecording = true
            updateStatusBarIcon()
        }
    }
}
```

### State Management
- **ObservableObject**: StatusBarManager, PermissionManager with `@Published` properties
- **SwiftUI Integration**: StatusBarMenu observes StatusBarManager state
- **Cross-Component**: NotificationCenter for Teams detection events

### Error Handling
- **Localized Errors**: All user-facing errors via `L10n.errorRecordingFailed()`
- **Structured Logging**: `Logger.shared.log()` with emoji and component tags
- **Recovery Patterns**: UnifiedScreenCapture auto-retry for recoverable errors ([UnifiedScreenCapture.swift:719-783](Sources/Audio/UnifiedScreenCapture.swift#L719))

### Audio Quality Patterns
- **bufferListNoCopy**: Use `AVAudioPCMBuffer(bufferListNoCopy:)` to avoid distortion ([SystemAudioCapture.swift:213-217](Sources/Audio/SystemAudioCapture.swift#L213))
- **File Stability**: Wait for file size stability before conversion ([UnifiedScreenCapture.swift:397-408](Sources/Audio/UnifiedScreenCapture.swift#L397))
- **Sample Rate Consistency**: Always 48kHz across all audio sources

## Localization

- **Languages**: English (default), French
- **Location**: `Sources/Resources/[lang].lproj/Localizable.strings`
- **Usage**: `L10n.keyName` pattern throughout codebase ([Localization.swift:29-110](Sources/Utils/Localization.swift#L29))
- **Key Areas**: Permission descriptions, error messages, UI labels
- **Adding Strings**:
  1. Add property to `L10n` extension in Localization.swift
  2. Add key/value to `en.lproj/Localizable.strings`
  3. Add key/value to `fr.lproj/Localizable.strings`

## Advanced Topics

### Health Monitoring System

UnifiedScreenCapture includes comprehensive health monitoring ([UnifiedScreenCapture.swift:301-383](Sources/Audio/UnifiedScreenCapture.swift#L301)):

```swift
// Checks every 5 seconds
private func performHealthCheck() {
    let timeSinceLastSample = now.timeIntervalSince(lastSampleTime)
    if timeSinceLastSample > 10.0 {
        Logger.shared.log("🩺 [HEALTH_MONITOR] ⚠️ No samples for \(timeSinceLastSample)s")
        checkStreamHealth()  // Diagnose: mic disconnected, display changes, etc.
    }
}
```

**What it checks**:
- Sample reception (audio/video streams)
- Microphone connection status
- Display configuration changes
- Memory usage and thermal state
- Competing applications (Zoom, Teams, Chrome)

### Error Recovery System

Automatic recovery for stream errors ([UnifiedScreenCapture.swift:499-817](Sources/Audio/UnifiedScreenCapture.swift#L499)):

**Recoverable Errors**:
- `-3821`: System stopped stream (usually system sleep/display change)
- `-3812`: Invalid parameter (temporary configuration issue)
- `-3801`: Stream configuration error

**Recovery Process**:
1. Detect error via `SCStreamDelegate`
2. Classify as recoverable/non-recoverable
3. Wait 2 seconds (exponential backoff)
4. Clean up old stream
5. Recreate with saved configuration
6. Retry up to 3 times
7. If all fail, notify user via callback

**Diagnostics** ([UnifiedScreenCapture.swift:521-717](Sources/Audio/UnifiedScreenCapture.swift#L521)):
- System state check (memory, uptime, thermal)
- Permission validation (screen recording, microphone)
- Resource availability (disk space, CPU)
- Display configuration comparison
- Competing app detection

### MOV to M4A Conversion

Critical for macOS 15+ ([UnifiedScreenCapture.swift:390-485](Sources/Audio/UnifiedScreenCapture.swift#L390)):

```swift
// Wait for file stability (max 15 seconds)
while Date() < deadline {
    if currentSize > 0 && currentSize == lastSize {
        stableCount += 1
        if stableCount >= 2 { break }  // Stable for 1 second
    }
    try? await Task.sleep(nanoseconds: UInt64(checkIntervalSeconds * 1_000_000_000))
}
```

**Why stability check is critical**:
- `SCRecordingOutput` writes asynchronously
- File may exist but still being written
- AVAssetExportSession fails on incomplete files
- Need 2 consecutive checks with same size

### Permission Testing Implementation

Real functional tests instead of status checks ([PermissionManager.swift:141-174](Sources/Permissions/PermissionManager.swift#L141)):

**Accessibility Test**:
```swift
// Test if we can access Finder windows
let finderApp = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.apple.finder"
).first
let appElement = AXUIElementCreateApplication(pid)
var windowsValue: CFTypeRef?
let result = AXUIElementCopyAttributeValue(
    appElement, kAXWindowsAttribute as CFString, &windowsValue
)
return result == .success  // Actually try to read, don't just check status
```

**Screen Recording Test** (macOS Sequoia 2024+):
```swift
// Try to get shareable content - only works if permission granted
let content = try await SCShareableContent.excludingDesktopWindows(
    false, onScreenWindowsOnly: true
)
return !content.displays.isEmpty
```

### Teams Detection Deep Dive

Multi-signal decision system ([TeamsMeetingDecider.swift](Sources/Calendar/TeamsMeetingDecider.swift)):

**Signal Priority**:
1. **Log Events** (highest): Explicit START/END markers
2. **Window + Mic**: Both required for fallback detection
3. **Window Only**: Ambiguous - could be ended meeting
4. **Mic Only**: Ambiguous - could be other app

**Environment Abstraction** ([TeamsDetectionEnvironment.swift](Sources/Calendar/TeamsDetectionEnvironment.swift)):
- Allows testing with mock environments
- Production implementation uses real Accessibility API
- Test implementation uses controlled state

## Important Implementation Notes

### Audio Buffer Management

**Critical Pattern** ([SystemAudioCapture.swift:213-217](Sources/Audio/SystemAudioCapture.swift#L213)):
```swift
// ✅ CORRECT - bufferListNoCopy avoids distortion
guard let audioBuffer = AVAudioPCMBuffer(
    pcmFormat: format,
    bufferListNoCopy: audioBufferList.unsafePointer
) else { return }

// ❌ WRONG - CMSampleBufferCopyPCMDataIntoAudioBufferList causes distortion
```

**Why**: Copying PCM data introduces audio artifacts. Direct buffer access required.

### StatusBar App Requirements

**Critical Setup** ([MeetingRecorderApp.swift:28-30](Sources/MeetingRecorderApp.swift#L28)):
```swift
NSApp.windows.forEach { $0.orderOut(nil) }  // Hide all windows
NSApp.setActivationPolicy(.accessory)  // No dock icon, status bar only
```

**Why direct executable required**:
- `swift run` doesn't properly set activation policy
- Status bar items don't appear correctly
- Permission dialogs may not show

### File Naming Conventions

**Output Files**:
- Format: `meeting_YYYY-MM-DD_HH-mm-ss.m4a` ([AudioMixer.swift:24](Sources/Audio/AudioMixer.swift#L24))
- Unified: `meeting_unified_YYYY-MM-DD_HH-mm-ss.mov` → `.m4a` ([UnifiedScreenCapture.swift:106](Sources/Audio/UnifiedScreenCapture.swift#L106))
- Location: `~/Documents/` (user's Documents folder)

**Temporary Files**:
- Microphone: `recording_{timestamp}.wav` ([MicrophoneCapture.swift:35](Sources/Audio/MicrophoneCapture.swift#L35))
- System Audio: `system_audio_{timestamp}.wav` ([SystemAudioCapture.swift:67](Sources/Audio/SystemAudioCapture.swift#L67))
- Auto-deleted after mixing ([AudioMixer.swift:58-65](Sources/Audio/AudioMixer.swift#L58))

# 📋 MeetingRecorder - Project Index

## 🎯 Project Overview

**MeetingRecorder** is a native macOS application that provides automatic meeting recording with Teams detection and system audio + microphone capture. The application runs from the status bar and can automatically detect and record Teams meetings while combining system audio and microphone input into high-quality M4A files.

### 🏆 Current Status: **MVP Complete** ✅

## 📚 Quick Navigation

| Section | Description | Status |
|---------|-------------|--------|
| [🏗️ Architecture](#-project-architecture) | Core system design and module organization | ✅ Complete |
| [⚡ Key Features](#-key-features) | Implemented functionality overview | ✅ MVP Ready |
| [🔧 Development](#-development-guide) | Build, test, and deployment instructions | ✅ Ready |
| [📖 Documentation](#-documentation-index) | Complete documentation reference | ✅ Comprehensive |
| [🚀 Usage](#-usage-guide) | End-user instructions and workflows | ✅ User-Ready |

---

## 🏗️ Project Architecture

### Core Modules

#### 🎤 Audio System
**Location**: `Sources/Audio/`
- **AudioMixer.swift** - Real-time audio mixing and M4A export
- **MicrophoneCapture.swift** - AVAudioEngine microphone recording
- **SystemAudioCapture.swift** - ScreenCaptureKit system audio capture  
- **UnifiedScreenCapture.swift** - macOS 15+ unified audio/video capture

**Key Features**:
- 48kHz stereo recording
- Real-time mixing without feedback
- High-quality AAC compression
- Automatic temp file cleanup

#### 🖥️ Status Bar Interface
**Location**: `Sources/StatusBar/`
- **StatusBarManager.swift** - Main application controller and Teams integration
- **StatusBarMenu.swift** - User interface and menu system

**Key Features**:
- Animated recording icons
- Real-time timer display
- Auto-recording controls
- Teams detection status

#### 🔐 Permission Management
**Location**: `Sources/Permissions/`
- **PermissionManager.swift** - Complete macOS permission handling

**Manages**:
- Microphone access (AVFoundation)
- Screen recording (ScreenCaptureKit)
- Documents folder access
- Accessibility API (Teams detection)

#### 🔍 Teams Detection
**Location**: `Sources/Calendar/`
- **TeamsDetector.swift** - Automatic Teams meeting detection

**Detection Methods**:
- Process monitoring
- Window title analysis
- Accessibility API integration
- Real-time status updates

#### 🎓 Onboarding System
**Location**: `Sources/Onboarding/`
- **OnboardingManager.swift** - First-launch flow coordination
- **OnboardingView.swift** - Permission request interface
- **OnboardingViewModel.swift** - Onboarding business logic

#### 🛠️ Utilities
**Location**: `Sources/Utils/`
- **Logger.swift** - Comprehensive logging system
- **Localization.swift** - Multi-language support (EN/FR)

---

## ⚡ Key Features

### ✅ Implemented (MVP Ready)

| Feature | Component | Status |
|---------|-----------|--------|
| **Status Bar Interface** | StatusBarManager | 🟢 Production Ready |
| **Manual Recording** | AudioMixer + Captures | 🟢 Production Ready |
| **System Audio Capture** | SystemAudioCapture | 🟢 Production Ready |
| **Microphone Recording** | MicrophoneCapture | 🟢 Production Ready |
| **Audio Mixing** | AudioMixer | 🟢 Production Ready |
| **M4A Export** | AudioMixer | 🟢 Production Ready |
| **Permission Management** | PermissionManager | 🟢 Production Ready |
| **Teams Detection** | TeamsDetector | 🟢 Production Ready |
| **Auto Recording** | StatusBarManager | 🟢 Production Ready |
| **Onboarding Flow** | OnboardingManager | 🟢 Production Ready |
| **Localization** | Localization | 🟢 EN/FR Support |

### 🔄 In Development

| Feature | Priority | Target |
|---------|----------|--------|
| Calendar Integration | Medium | Phase 2 |
| Smart Notifications | Low | Phase 2 |
| Advanced Preferences | Low | Phase 3 |

---

## 🔧 Development Guide

### 📋 Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| **macOS** | 12.3+ | ScreenCaptureKit requirement |
| **Swift** | 5.9+ | Language version |
| **Xcode** | 15.0+ | Development environment |

### 🚀 Quick Start

```bash
# Clone and build
git clone https://github.com/florianchevallier/meeting-recorder.git
cd meeting-recorder
swift build

# Launch app (status bar mode)
./.build/debug/MeetingRecorder

# Run tests
swift test
```

### 🏗️ Build Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `swift build` | Debug build | `.build/debug/` |
| `swift build -c release` | Release build | `.build/release/` |
| `./debug_app.sh` | App bundle | `.build/MeetingRecorder.app` |
| `swift test` | Run test suite | Console output |

### 📊 Project Structure
```
MeetingRecorder/
├── 📁 Sources/
│   ├── 🎯 MeetingRecorderApp.swift     # Entry point
│   ├── 📁 Audio/                       # Audio pipeline
│   ├── 📁 StatusBar/                   # User interface  
│   ├── 📁 Permissions/                 # System access
│   ├── 📁 Calendar/                    # Teams detection
│   ├── 📁 Onboarding/                  # First launch
│   ├── 📁 Utils/                       # Shared utilities
│   └── 📁 Resources/                   # Assets & localization
├── 📁 Tests/                           # Test suite
├── 📄 Package.swift                    # SPM configuration
└── 📚 Documentation/                   # Project docs
```

---

## 📖 Documentation Index

### 📚 Core Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| **README.md** | Project overview and quick start | All users |
| **CLAUDE.md** | Detailed architecture and development | Developers |
| **CONTRIBUTING.md** | Contribution guidelines | Contributors |
| **DEPLOYMENT.md** | Distribution and deployment | DevOps |
| **INSTALLATION_GUIDE.md** | End-user installation | Users |

### 🔧 Technical Reference

| Topic | Location | Content |
|-------|----------|---------|
| **Audio Pipeline** | StatusBarManager.swift:198-328 | Recording workflow |
| **Permission Flow** | PermissionManager.swift:176-185 | Permission requests |
| **Teams Detection** | TeamsDetector.swift | Detection algorithms |
| **Error Handling** | Logger.swift | Logging standards |
| **Localization** | Resources/[lang].lproj/ | Multi-language support |

### 🎯 Code References

| Function | File:Line | Purpose |
|----------|-----------|---------|
| `startRecording()` | StatusBarManager.swift:198 | Main recording trigger |
| `mixAudioFiles()` | AudioMixer.swift:6 | Audio mixing logic |
| `checkAllPermissions()` | PermissionManager.swift:20 | Permission validation |
| `handleTeamsMeetingStatusChange()` | StatusBarManager.swift:60 | Auto-recording logic |

---

## 🚀 Usage Guide

### 🎬 Recording Workflow

1. **First Launch**: App requests all necessary permissions via onboarding
2. **Status Bar**: Click 🎤 icon to access controls  
3. **Manual Recording**: Start/Stop via menu
4. **Auto Recording**: Automatic Teams meeting detection
5. **File Output**: `~/Documents/meeting_YYYY-MM-DD_HH-mm-ss.m4a`

### 🔐 Required Permissions

| Permission | Purpose | Auto-Requested |
|------------|---------|----------------|
| **🎤 Microphone** | Voice recording | ✅ Yes |
| **📺 Screen Recording** | System audio capture | ✅ Yes |
| **📁 Documents** | File storage | ✅ Yes |
| **♿ Accessibility** | Teams detection | ✅ Yes |

### ⚙️ Configuration Options

| Setting | Control | Default |
|---------|---------|---------|
| **Auto Recording** | Status bar menu | Enabled |
| **Audio Quality** | AudioMixer.swift:47 | High (M4A/AAC) |

---

## 🧪 Testing & Quality

### 🔍 Test Coverage

| Module | Test File | Coverage |
|--------|-----------|----------|
| **Core Logic** | MeetingRecorderTests.swift | Basic structure |
| **Manual Testing** | Debug logging | Comprehensive |
| **Permission Flow** | Onboarding system | User validated |

### 🐛 Debugging

```bash
# View real-time logs (macOS Unified Logging)
log stream --predicate 'subsystem == "com.meetingrecorder.app"' --level debug

# Or open Console.app
open -a Console  # Search for "Meety"

# Reset permissions for testing
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app

# Check generated files
ls -la ~/Documents/meeting_*.m4a
```

---

## 🗺️ Roadmap

### 📅 Phase 2: Enhanced Automation
- [ ] **Calendar Integration**: EventKit for meeting schedules
- [ ] **Smart Notifications**: Discrete recording alerts
- [ ] **Intelligent Naming**: Meeting title extraction

### 📅 Phase 3: Advanced Features  
- [ ] **User Preferences**: Quality/folder settings
- [ ] **Recording Management**: File browser interface
- [ ] **Export Options**: Quick sharing tools
- [ ] **Shortcuts Integration**: macOS automation

---

## 🤝 Contributing

### 🔧 Development Setup

1. **Fork Repository**: GitHub fork workflow
2. **Feature Branch**: `git checkout -b feature/name`
3. **Development**: Follow existing patterns
4. **Testing**: `swift build && swift test`
5. **Documentation**: Update relevant docs
6. **Pull Request**: Clear description with testing notes

### 📏 Code Standards

- **Swift Style**: SwiftLint compatible
- **Architecture**: MVVM with ObservableObject
- **Comments**: DocC format for public APIs
- **Error Handling**: Comprehensive with user-friendly messages
- **Logging**: Use Logger.shared for all output

---

## 📞 Support

### 🔗 Resources

| Resource | Link | Purpose |
|----------|------|---------|
| **Issues** | GitHub Issues | Bug reports |
| **Discussions** | GitHub Discussions | Feature requests |
| **Documentation** | This repository | Technical reference |
| **License** | MIT License | Usage terms |

### ⚠️ Known Issues

| Issue | Workaround | Status |
|-------|------------|--------|
| Permission dialogs may require app restart | Restart after permissions | Tracked |
| Teams detection accuracy varies | Manual override available | Improving |

---

## 📊 Project Metrics

### 📈 Development Stats

| Metric | Value | Notes |
|--------|-------|-------|
| **Total Files** | 17 Swift files | Clean architecture |
| **Lines of Code** | ~2,500 lines | Well-documented |
| **Test Coverage** | Basic | Needs expansion |
| **Documentation** | Comprehensive | Multi-format |
| **Localization** | EN/FR | Expandable |

### 🎯 Quality Indicators

| Indicator | Status | Evidence |
|-----------|--------|----------|
| **MVP Complete** | ✅ | All core features working |
| **Production Ready** | ✅ | Error handling + logging |
| **User Tested** | ✅ | Onboarding flow validated |
| **Documented** | ✅ | Multiple documentation formats |

---

*Generated by SuperClaude `/sc:index` - Last updated: 2025-01-27*