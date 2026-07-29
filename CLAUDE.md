# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ IMPORTANT RULES FOR CLAUDE

**DO NOT CREATE NEW MARKDOWN FILES**

- ❌ **NEVER** create files like `SETUP_GUIDE.md`, `DEPLOYMENT_GUIDE.md`, `TROUBLESHOOTING.md`, etc.
- ✅ **ALWAYS** put documentation directly in `CLAUDE.md` (this file)
- ✅ **ONLY** create files when explicitly requested by the user

**DO NOT ADD CO-AUTHORS TO GIT COMMITS**

- ❌ **NEVER** add any AI assistant as co-author in commits
- ✅ **ALWAYS** keep commits attributed to the human developer only

**NEVER COMMIT ON BEHALF OF THE USER**

- ❌ **NEVER** run `git commit` commands without explicit user instruction
- ✅ **ALWAYS** stage changes with `git add` and show status
- ✅ **ONLY** commit if the user explicitly asks "commit this" or "make a commit"

---

# Meety — macOS Meeting Recorder

## Project Overview

Native macOS status bar application that records meetings (system audio + microphone) with automatic Teams meeting detection and optional Whisper transcription. Produces high-quality M4A files in `~/Documents/`.

**Brand Name**: **Meety** — **Requirements**: macOS 15.0+, Swift 6 (strict concurrency)

## Essential Commands

### Build & Run
```bash
# Debug build and run (primary method)
swift build
./.build/debug/MeetingRecorder

# NEVER use `swift run` — always the direct executable
# (proper status bar behavior and permission handling)

# Release build
swift build -c release

# Create app bundle for distribution
./debug_app.sh
# Output: .build/MeetingRecorder.app, installed to /Applications
```

### Tests (Swift Testing)
```bash
swift test

# ⚠️ Local toolchain caveat: if you build with Command Line Tools and see
# "no such module 'Testing'", either accept the Xcode license and run with:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# The CI (full Xcode 16) runs tests without any workaround.
```

### Debugging
```bash
# Real-time logs (macOS Unified Logging; subsystem = bundle identifier)
log stream --predicate 'subsystem == "com.meetingrecorder.meety"' --level debug

# Last 100 entries
log show --predicate 'subsystem == "com.meetingrecorder.meety"' --last 100

# Reset permissions for testing
tccutil reset Microphone com.meetingrecorder.meety
tccutil reset ScreenCapture com.meetingrecorder.meety

# Check recordings
ls -la ~/Documents/meeting_*.m4a
```

## Architecture (post-rewrite)

SwiftPM executable, **zero dependencies**, Swift 6 language mode. Composition root
is `AppDependencies` (created by `AppDelegate`); dependencies flow by initializer
injection. The only retained singleton is `Logger.shared` (lock-protected).

```
Sources/
├── App/                    # Composition root & lifecycle
│   ├── MeetingRecorderApp.swift   # @main, hidden WindowGroup, .accessory policy
│   └── AppDependencies.swift      # Object graph (settings, monitor, coordinators…)
├── StatusBar/              # Status bar UI
│   ├── StatusBarController.swift  # NSStatusItem + NSPopover, 4 icon states
│   ├── StatusBarMenu.swift        # Popover SwiftUI (progress ring, panels)
│   ├── RecordingCoordinator.swift # Recording state machine, drives CaptureEngine
│   └── RecordingState.swift       # idle/starting/recording/recovering/stopping
├── Capture/                # ScreenCaptureKit pipeline
│   ├── CaptureEngine.swift        # actor: stream, recording output, recovery, health
│   ├── StreamDelegateBridge.swift # SCK delegate callbacks → actor + sample counting
│   ├── CaptureConfiguration.swift # Pure factories (config, filter, output URL)
│   ├── MediaConverter.swift       # MOV→M4A with stability pre-flight (injectable)
│   ├── CaptureDiagnostics.swift   # Deep -3821 diagnostics
│   ├── CaptureErrorClassifier.swift # -3821/-3812/-3801 → recoverable
│   └── CaptureEvent.swift         # recoveryAttempt/recovered/criticalError/unhealthy
├── TeamsDetection/         # Teams meeting detection
│   ├── TeamsMonitor.swift         # actor: 2s poll loop, AsyncStream<Bool>
│   ├── TeamsSignalSource.swift    # protocol + TeamsWindowClassifier
│   ├── LiveTeamsSignalSource.swift # AX windows, CoreAudio mic, logs.txt parsing
│   └── TeamsMeetingDecider.swift  # Pure decision logic
├── Permissions/
│   ├── PermissionMonitor.swift    # @Observable, 4 permissions, recheck on activation
│   ├── ScreenRecordingProbe.swift # 3-method SCK probe → value (no side effects)
│   └── PermissionStatus.swift     # Status enum + errors
├── Settings/
│   ├── SettingsStore.swift        # @Observable, UserDefaults injectable
│   ├── SettingsWindow.swift       # 3 tabs (General, Transcription, Permissions)
│   └── SettingsWindowController.swift # NSWindow reuse by identifier
├── Onboarding/
│   └── OnboardingCoordinator.swift # First launch → Permissions tab
├── Transcription/
│   ├── TranscriptionCoordinator.swift # @Observable: upload → poll → save .txt
│   ├── TranscriptionState.swift   # struct + pure reducer (testable)
│   ├── WhisperAPIClient.swift     # Sendable HTTP client
│   ├── EndpointResolver.swift     # Pure endpoint fallback (404 → next)
│   ├── MultipartBuilder.swift     # Pure multipart body (no force unwraps)
│   └── TranscriptionModels.swift  # Codable models + APIError
├── Utilities/
│   ├── Logger.swift               # os_log, leveled, throttled, @unchecked Sendable
│   ├── Localization.swift         # L10n (EN/FR)
│   ├── Constants.swift            # UI, TeamsDetection, Recording, Transcription, Permissions
│   └── FileSystemUtilities.swift  # Documents access, timestamped filenames (local TZ)
└── Resources/              # en/fr .strings, app icons
```

### Key Design Decisions

- **Actors** own mutable state: `CaptureEngine` (stream/output/continuation/retries),
  `TeamsMonitor` (polling loop). Everything UI-facing is `@MainActor @Observable`.
- **No NotificationCenter / Timer / Combine** in the new code: `AsyncStream` for
  events, async loops for polling, `TimelineView` for the recording duration.
- **State machine prevents the double-start race**: `start()` only accepted from `.idle`.
- **Stop finalization handshake** lives inside the actor: `stopCapture` →
  continuation resumed by `recordingOutputDidFinishRecording` OR by the file-stability
  fallback watcher (0.5s polls, 3 stable checks, 120s cap). Resumed exactly once.
- **Health monitoring actually works**: the bridge is attached as a lightweight
  sample-counting `SCStreamOutput` (buffers discarded) + MOV file-growth signal.
- **Recovery retries directly** (≤3, 2s delay) instead of waiting for a
  `didStopWithError` that never arrives after a failed restart.
- **`recordingOutput(didFailWithError:)` surfaces as `.criticalError`** with partial-MOV salvage.
- **Termination handshake**: `applicationShouldTerminate` → `.terminateLater` while
  recording, `shutdown()` finalizes the M4A, 60s watchdog guarantees exit.

### ScreenCaptureKit Configuration (do not change lightly)

```swift
// Filter: macOS 15 pattern — do NOT "simplify" to excludingWindows: []
SCContentFilter(display: display, including: applications, exceptingWindows: [])

// Config: real display dimensions, 15fps, showsCursor, capturesAudio,
// excludesCurrentProcessAudio, captureMicrophone (default device), HEVC .mov
```

## Teams Detection

Four signals (polled every 2s by `TeamsMonitor`):
1. **Teams running** — bundle IDs: `com.microsoft.teams2`, `com.microsoft.teams`, `com.microsoft.Teams`
2. **Log parsing** — `~/Library/Application Support/Microsoft/Teams/logs.txt`, last 20 lines, START `s::;m::1;a::1` / END `a::3` (old Teams path, kept for parity)
3. **Meeting window** — Accessibility API + `TeamsWindowClassifier` (exclusions beat keywords)
4. **Mic active** — CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere`

Decision (pure, tested): explicit START → active; explicit END → inactive;
otherwise window+mic → active; anything else → inactive.

**Recording auto-starts on meeting begin and intentionally continues after the meeting ends.**

## Permissions (4)

Managed by `PermissionMonitor` (rechecked on app activation):
1. **Microphone** — `AVCaptureDevice`
2. **Screen Recording** — 3-method functional probe (`ScreenRecordingProbe`), conservative `.notDetermined` mapping, `-3801`/`-3804` → denied
3. **Documents** — write/delete test file
4. **Accessibility** — `AXIsProcessTrusted` + functional Finder-window probe

## Transcription (Whisper API)

Optional (Settings → Transcription). Flow: multipart POST (field `audio` + 8 params)
to candidate endpoints `[process, jobs, transcriptions, transcribe]` until non-404 →
202 + jobId → poll `GET /jobs/{id}` every 5s (max 360) → download result →
`<recording>.txt` next to the M4A. UI state is a pure reducer (`TranscriptionStateReducer`).

Note: the app is **not sandboxed**, so `com.apple.security.network.client=false` in
the entitlements is inert. If sandboxing is ever enabled, that key must become `true`.

## Localization

EN (default) + FR via `L10n` (`Bundle.module`). Both `.strings` files must carry
identical key sets — enforced by `Tests/L10nParityTests.swift`.

## Logging

`Logger.shared` — os_log, subsystem = bundle identifier. Leveled API:
`debug/info/warning/error(_:component:)`, plus `logThrottled`. The legacy `log(_:)`
shim is transitional — don't use it in new code.

## Code Signing & Distribution (GitHub Actions)

`git push` of a `v*` tag → CI builds universal binary, signs with Developer ID,
creates + signs DMG, notarizes via notarytool, staples, creates the GitHub Release,
then `scripts/release.sh` updates the Homebrew cask.

```bash
./scripts/release.sh 0.1.23   # full release (tag → CI → cask)
```

**7 GitHub secrets required** (already configured): `DEVELOPER_ID_CERTIFICATE` (base64 P12),
`CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`, `SIGNING_IDENTITY`, `APPLE_ID`,
`APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.

Release notes are AI-generated (Gemini, OpenAI fallback) from conventional commits
by `.github/scripts/generate-release-notes.py` (`GOOGLE_API_KEY` secret).

## Testing

Swift Testing (`@Test`/`#expect`) in `Tests/`, run by CI on every PR and tag:
- `TeamsMeetingDeciderTests` — full decision matrix
- `TeamsWindowClassifierTests` — keywords/exclusions/case
- `FilenameGenerationTests` — local timezone, injected date
- `SettingsStoreTests` — defaults, persistence round-trip, URL validation
- `EndpointResolverTests`, `MultipartBuilderTests`
- `TranscriptionStateMachineTests` — reducer transitions
- `CaptureErrorClassifierTests` — recoverable codes
- `FileStabilityWaitTests` — injected clock/probes
- `L10nParityTests` — EN/FR key parity

Pure logic is designed for tests: `TeamsMeetingDecider`, `TeamsWindowClassifier`,
`CaptureErrorClassifier`, `EndpointResolver`, `MultipartBuilder`, `MediaConverter`
(injectable clock/file probes), `TranscriptionStateReducer`, `SettingsStore`
(injectable `UserDefaults`).
