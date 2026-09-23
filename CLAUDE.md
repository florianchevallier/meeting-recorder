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

Native macOS status bar application that records meetings (system audio via Core Audio
process taps + microphone) with automatic Teams meeting detection and optional Whisper
transcription. Produces AAC M4A files in `~/Documents/`.

**Brand Name**: **Meety** — **Requirements**: macOS 26.0+ (Tahoe), Swift 6 language mode, `swift-tools-version: 6.2`, Xcode 26.x

## Essential Commands

### Build & Run
```bash
# ⚠️ Always build with the Xcode toolchain. The Command Line Tools on macOS 27
# ship a Swift 6.4 / SDK 27 combo where SwiftUI's `@State` is a macro whose
# plugin (SwiftUIMacros) only exists inside Xcode → "plugin for module
# 'SwiftUIMacros' not found". Either `sudo xcode-select -s /Applications/Xcode.app`
# once, or prefix every command:
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

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
swift test                                   # same DEVELOPER_DIR caveat as above

# CI runs exactly this (warnings are errors there):
swift build -Xswiftc -warnings-as-errors
swift test --parallel -Xswiftc -warnings-as-errors
```

### Debugging
```bash
# Real-time logs (macOS Unified Logging; subsystem = bundle identifier)
log stream --predicate 'subsystem == "com.meetingrecorder.meety"' --level debug
log stream --predicate 'subsystem == "com.meetingrecorder.meety.debug" AND category == "capture"' --level debug

# Last 100 entries
log show --predicate 'subsystem == "com.meetingrecorder.meety"' --last 100

# Reset permissions for testing (AudioCapture = "System Audio Recording Only")
tccutil reset Microphone com.meetingrecorder.meety
tccutil reset AudioCapture com.meetingrecorder.meety
tccutil reset Accessibility com.meetingrecorder.meety
tccutil reset Calendar com.meetingrecorder.meety
tccutil reset All com.meetingrecorder.meety.debug   # safe catch-all for the debug bundle

# Check recordings
ls -la ~/Documents/meeting_*.m4a
```

## Architecture

SwiftPM executable, **zero dependencies**, Swift 6 language mode, `swift-tools-version: 6.2`
with upcoming features `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`,
`MemberImportVisibility`, `ExistentialAny`. Composition root is `AppDependencies`
(created by `AppDelegate`); dependencies flow by initializer injection. No singletons
(`Log` is a namespace of `os.Logger` values).

```
Sources/
├── App/                    # Composition root & lifecycle (pure AppKit, no SwiftUI scene)
│   ├── MeetingRecorderApp.swift   # @main enum → NSApplication + AppDelegate, terminate handshake
│   └── AppDependencies.swift      # Object graph (settings, permissions, coordinators…)
├── StatusBar/              # Status bar UI
│   ├── StatusBarController.swift  # NSStatusItem + NSPopover, IconState (pure) + cached NSImages
│   ├── StatusBarMenu.swift        # Popover SwiftUI; TimelineView only around the duration/ring
│   ├── CalendarMenuSection.swift  # Today's meetings; TimelineView(.everyMinute) over a pure agenda
│   ├── RecordingCoordinator.swift # Drives CaptureEngine, permission gating, RecordingError + Remedy
│   └── RecordingState.swift       # idle/starting/recording/recovering/stopping + pure transition()
├── Capture/                # Core Audio process-tap pipeline (audio only, AAC direct)
│   ├── CaptureEngine.swift        # actor: tap restarts, health loop, deterministic stop/finalize
│   ├── ProcessTapController.swift # CATapDescription + private aggregate device + IOProc
│   ├── AudioFileWriter.swift      # AVAssetWriter .m4a (AAC mono 48 kHz), converters, mixdown
│   ├── DeviceChangeObserver.swift # Default in/out device listeners → AsyncStream
│   ├── CaptureCounters.swift      # Atomic counters/peaks written by the IO path
│   ├── VoiceActivity.swift        # Mic vs system RMS per 250 ms → `<rec>.activity.json`
│   ├── CaptureHealth.swift        # HealthEvaluator (pure): stalled / dropping / systemSilent
│   ├── CaptureStreamLayout.swift  # Aggregate buffer index → tap / microphone (pure)
│   ├── CaptureFormat.swift        # Canonical format + AAC settings
│   ├── CaptureFailure.swift       # Error enum (+ OSStatus FourCC rendering)
│   ├── CaptureErrorClassifier.swift # CaptureFailure → restartTap / fatal (pure)
│   ├── CaptureEvent.swift         # started/restarting/restarted/degraded/systemAudioDetected/failed
│   ├── CoreAudioProperties.swift  # Typed AudioObjectGetPropertyData wrappers
│   └── SystemAudioPermissionProbe.swift # Tone + self-tap probe for the TCC status (no private API)
├── TeamsDetection/         # Event-driven Teams meeting detection (@MainActor)
│   ├── TeamsMonitor.swift         # Merges signals, 3 s debounce, AsyncStream<Bool>
│   ├── TeamsSignalSource.swift    # TeamsSignalEvent, protocol, TeamsApp, TeamsWindowClassifier
│   ├── LiveTeamsSignalSource.swift # Composes the three observers below
│   ├── TeamsProcessObserver.swift # NSWorkspace launch/terminate → Teams pids
│   ├── TeamsMicrophoneObserver.swift # CoreAudio listener trigger + per-process "running input" read
│   ├── TeamsWindowObserver.swift  # AXObserver + coalesced rescan + 15 s fallback poll
│   └── TeamsMeetingDecider.swift  # Pure: window && mic
├── Calendar/               # EventKit agenda, event-named recordings, reminders (@MainActor)
│   ├── CalendarEvent.swift        # Sendable snapshot + Participant, expectedSpeakerCount
│   ├── CalendarEventSource.swift  # Protocol + EventKitCalendarSource (EKEventStore, EKEventStoreChanged)
│   ├── CalendarMatcher.swift      # Pure: event ↔ recording, filename date, meeting link
│   ├── CalendarAgenda.swift       # Pure: upcoming/past for the popover + MeetingReminderPlanner
│   ├── CalendarMonitor.swift      # @Observable: today's events + recordings on disk, event-driven
│   ├── MeetingMetadata.swift      # `<recording>.meeting.json` sidecar (participants)
│   └── MeetingReminderScheduler.swift # UNUserNotificationCenter + Record action (inert without bundle)
├── Permissions/
│   ├── PermissionMonitor.swift    # @Observable, 4 permissions, synchronous refresh, injected probes
│   └── PermissionStatus.swift     # PermissionKind, PermissionStatus, SystemAudioOutcome, errors
├── Settings/
│   ├── SettingsStore.swift        # @Observable, DefaultsKey-backed, UserDefaults injectable
│   ├── SettingsWindow.swift       # 4 tabs; selected tab lives in SettingsWindowModel
│   └── SettingsWindowController.swift # NSWindow (created once), NSWindowDelegate → onClose
├── Onboarding/
│   └── OnboardingCoordinator.swift # decide() pure + Observations-driven completion
├── Transcription/          # WhisperX server client + transcript rendering
│   ├── TranscriptionCoordinator.swift # @Observable queue: upload → poll → JSON → .txt, resume, cancel
│   ├── TranscriptionState.swift   # struct + pure reducer + TranscriptionProgress (log → %)
│   ├── TranscriptionHints.swift   # Pure: calendar → speaker range + sanitized prompt
│   ├── Transcript.swift           # WhisperX JSON model (segments, words, SPEAKER_xx)
│   ├── SpeakerLabeler.swift       # Pure: manual names > mic-dominant "me" > last 1:1 match
│   ├── TranscriptRenderer.swift   # Pure: header + `[mm:ss] Name: text` turns
│   ├── TranscriptFiles.swift      # Sidecars ↔ Document, (re)writes the .txt, saves names
│   ├── SpeakerNamesWindow.swift   # NSWindow + SwiftUI to name speakers
│   ├── WhisperAPIClient.swift     # Sendable HTTP client (X-API-Key, upload from file, DELETE)
│   ├── EndpointResolver.swift     # Pure URLs: <base>/process, /jobs/{id}, /jobs/{id}/result
│   ├── MultipartBuilder.swift     # Multipart body streamed to a temp file
│   └── TranscriptionModels.swift  # Request/response models, PendingTranscriptionJob, APIError
├── LiveTranscription/      # On-device live transcript while recording (Apple SpeechAnalyzer)
│   ├── LiveTranscript.swift       # Pure: segments per speaker (volatile → final), Markdown lines
│   ├── LiveSpeechTranscriber.swift # actor: one SpeechAnalyzer + SpeechTranscriber per source
│   ├── LiveTranscriptionCoordinator.swift # @Observable: session per recording, `<rec>.live.md`
│   └── LiveTranscriptPanel.swift  # Floating non-activating NSPanel + SwiftUI transcript view
├── Utils/
│   ├── Log.swift                  # os.Logger per category (app, capture, recording, teams, …)
│   ├── DefaultsKey.swift          # Every UserDefaults key (legacy raw values preserved)
│   ├── Localization.swift         # L10n (EN/FR)
│   ├── Constants.swift            # UI, TeamsDetection, Recording, App, Transcription, Permissions
│   ├── FileSystemUtilities.swift  # Documents access, timestamped filenames (local TZ)
│   ├── RecordingFiles.swift       # Every sidecar URL of a recording
│   └── KeychainStore.swift        # Generic passwords (transcription API key)
└── Resources/              # en/fr .strings, app icons
```

### Key Design Decisions

- **Audio only.** System audio comes from a Core Audio process tap
  (`CATapDescription(stereoGlobalTapButExcludeProcesses:)`, private, unmuted) inside a
  private aggregate device whose clock master is the default output device; the default
  microphone is a drift-compensated sub-device. One IOProc delivers both streams in
  sync. No ScreenCaptureKit, no video, no MOV, no conversion step.
- **One writer, many taps.** `AudioFileWriter` keeps the `.m4a` open for the whole
  recording; a device change or a stall (no IO callback for 3 s) rebuilds only the tap
  (≤3 attempts, 1 s apart) and inserts silence for the gap (capped at 10 s) so the file
  stays aligned with wall-clock time. Fragments every 10 s keep a crashed recording playable.
- **Sample-rate changes rebuild the tap.** A Bluetooth headset in A2DP (44.1/48 kHz) drops
  to its hands-free profile (16 kHz) as soon as the mic opens; formats built for the old
  rate made the whole file (and the live transcript) play ~3× fast. `DeviceChangeObserver`
  listens to the default devices' nominal rate, and `HealthEvaluator` compares the frames
  actually delivered per second with the format's rate (`.sampleRateMismatch`, ≥ 10 % over
  2 intervals, ≤ `maxSampleRateRestarts` rebuilds) as a safety net. Device-list changes
  ignore Meety's own private aggregates (`aggregateUIDPrefix`), otherwise every rebuild
  triggered the next one (restart loop every ~1.6 s).
- **Deterministic stop.** `stop()` returns the same task to concurrent callers, awaits any
  restart in flight, tears the tap down, finishes the writer (10 s ceiling) and renames
  `<name>.partial.m4a` → `<name>.m4a`. No stored continuation, no file-stability polling.
- **IO path stays lean.** The IO block copies each stream into a PCM buffer, updates
  atomics (`CaptureCounters`) and hops to the writer queue; back-pressure drops cycles
  above ~5 s of queued audio and counts them. `AudioFileWriter` is the only
  `@unchecked Sendable` in the module (queue-confined by construction).
- **Mixdown**: tap and mic are rate-converted to 48 kHz keeping channels, averaged to
  mono, summed, soft-clipped above ±0.8, encoded AAC-LC 96 kbps. One track on purpose
  (Whisper/ffmpeg only decode the first stream; QuickTime plays one).
- **State machine** (`RecordingState.transition`) is pure and tested; the coordinator
  stores every `Task` it creates (start, stop, events, permission watch).
- **Everything UI-facing is `@MainActor @Observable`**; AppKit observes it through
  `Observations { }` loops (macOS 26), never re-armed `withObservationTracking`.
- **Termination handshake**: `applicationShouldTerminate` → `.terminateLater` while a
  session exists, `shutdown()` finalizes, `Constants.App.terminationWatchdog` (15 s,
  above the 10 s finalization ceiling) guarantees exit.
- `.defaultIsolation(MainActor.self)` is deliberately **not** enabled yet (follow-up).

## Teams Detection

Event-driven, zero periodic work while Teams is not running (`TeamsMonitor`, `@MainActor`):
1. **Teams running** — NSWorkspace launch/terminate notifications; any bundle id starting
   with `com.microsoft.teams` (new Teams, classic, helpers).
2. **Meeting window** — `AXObserver` on each Teams pid (window created / focused /
   title changed / destroyed) → coalesced (300 ms) rescan off-main → `TeamsWindowClassifier`
   (exclusions beat keywords). AX messaging timeout 0.5 s. Fallback rescan every 15 s
   while Teams runs; nothing at all without Accessibility.
3. **Mic active** — trigger: `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default
   input (plus process-list / default-device listeners); truth: `kAudioProcessPropertyIsRunningInput`
   read for every Teams process object, so Meety's own capture never counts.

Decision (pure, tested): window **and** mic → active. Transitions are debounced 3 s.
The old `logs.txt` signal was removed (new Teams never writes it).

**Recording auto-starts on meeting begin and intentionally continues after the meeting ends.**

## Permissions (4)

`PermissionMonitor` — `refresh()` is synchronous and side-effect free; triggers are app
activation, System Settings (de)activation, and a bounded 30 × 1 s recheck after a deep link.
1. **Microphone** — `AVAudioApplication.recordPermission` / `requestRecordPermission()`.
2. **System Audio Recording** (TCC "System Audio Recording Only", `Privacy_AudioCapture`) —
   no public query API. Status is `unknownUntilFirstUse` until either a recording receives
   non-silent system audio (`.systemAudioDetected`) or the user runs **Verify**
   (`SystemAudioPermissionProbe`: plays a −30 dBFS tone and taps our own process; silence ⇒
   denied). Persisted in `DefaultsKey.systemAudioPrompted/Verified`. The first tap start
   shows the TCC prompt and blocks until answered — `start()` has no timeout for that reason.
3. **Accessibility** — `AXIsProcessTrusted`; prompt via `AXIsProcessTrustedWithOptions` then
   deep link. `denied` only after we prompted once.
4. **Calendar** (optional) — `EKEventStore.authorizationStatus(for: .event)`; only
   `.fullAccess` counts (write-only ⇒ denied). Prompt via `requestFullAccessToEvents()`,
   deep link `Privacy_Calendars`. Needs `NSCalendarsFullAccessUsageDescription` and the
   hardened-runtime entitlement `com.apple.security.personal-information.calendars`.
   Blocks neither onboarding nor recording.

Onboarding completes on microphone + accessibility (system audio can't be granted without
recording), or when the user closes the window. `RecordingCoordinator.start()` gates on
microphone granted and system audio not denied, checks that `~/Documents` is writable, and
surfaces `RecordingError` with a `Remedy` (deep link / open folder). Microphone revocation
mid-recording stops and finalizes the recording.

## Calendar

EventKit, i.e. every account already in Calendar.app (Exchange/Outlook, iCloud, Google):
no OAuth, no network. `CalendarMonitor` fetches today → now + 24 h (all-day and cancelled
events dropped, rooms/resources dropped from attendees) on events only: `EKEventStoreChanged`,
`NSCalendarDayChanged`, permission grant / Settings toggle (store `reset()` first), popover
open, and the end of each recording. No polling.
- **Calendar picker** (Settings → Calendar): `calendarSelectedIDs` (`EKCalendar.calendarIdentifier`);
  `nil` = all (default). The first toggle makes it explicit, so calendars added later stay out.
  Filtering happens in the EventKit predicate; an empty selection means no events.
- **Popover**: up to 3 upcoming (incl. in progress, "in N min", join link) and 3 past
  meetings of today; past ones link their recording (▶︎ / transcript / Finder).
- **Recording ↔ event** (`CalendarMatcher`, pure): a recording started in
  `[start − 10 min, end)` belongs to the event; a meeting link wins, then the closest start.
  Linking reads the start from the filename, so it works for old recordings too.
- **Filename**: `meeting_<timestamp>_<sanitized title>.m4a` (≤60 chars, no `/:\?*"<>|`).
- **Sidecar**: `<recording>.meeting.json` (event, organizer, attendees + status) for
  diarization: the attendee count (minus declined, ≥2) becomes `maxSpeakers`, the title and
  names go into the prompt (see Transcription).
- **Reminders** (Settings → Calendar, off by default): notifications N min before, `Record`
  action → `coordinator.start()`. Replaced wholesale on every change (`meety.reminder.` ids).
  Inert when run as a bare binary (`UNUserNotificationCenter` needs a bundle id).

## Transcription (WhisperX server)

Server: `apps/api` of `~/Projects/innovation-transcript` (WhisperX + pyannote). Base URL
setting ends with `/api`. Optional API key (Settings → Transcription, stored in the keychain)
goes in `X-API-Key`; every request also sends `ngrok-skip-browser-warning`.

Automatic after a recording when Settings → General → Transcription is on, or on demand
from the popover (Transcribe / Transcribe again on past meetings). `TranscriptionCoordinator`
runs one recording at a time from a queue:
1. `TranscriptionHints` (pure) from the `.meeting.json` event: `minSpeakers = 1`,
   `maxSpeakers = invitees` (a range: `nbSpeaker` would force pyannote to find exactly that
   many voices); without an event `maxSpeakers` = the setting. `initialPrompt` = title +
   participant names + glossary setting, quotes/`$`/backticks/control chars stripped, ≤ 400 chars.
2. `POST /process` (`outputFormat=json`), body streamed from a temp file →
   `<rec>.transcription-job.json` {jobId} so a relaunch resumes (`resumePending` at launch).
3. Poll `GET /jobs/{id}` every 5 s (max 360); `[NN%]` in `lastLog` feeds the progress bar.
4. `GET /jobs/{id}/result` → `<rec>.transcript.json` (raw) → `<rec>.txt` rendered →
   `DELETE /jobs/{id}` (audio and result gone from the server).
Network errors keep the job file (resumed next launch); a failed/unknown job deletes it
(Retry re-uploads). Cancel deletes the server job.

**Speaker names** (`SpeakerLabeler`, pure), in priority order: names typed in the
Speakers window (`<rec>.speakers.json`); "me" = the speaker whose words mostly (≥ 60 %,
25 pts ahead of the next) fall in windows where the mic is ≥ −40 dBFS and ≥ 10 dB above the
system audio (`<rec>.activity.json`, written by `AudioFileWriter` at finalize, not written
without a microphone); then, if exactly one speaker and one expected participant are left,
they match (names both sides of a 1:1). Rooms and laptop-speaker echo give no "me".
Thresholds are first guesses, to calibrate on real recordings. Renaming re-renders the
`.txt` from the JSON, no network.

Note: the app is **not sandboxed**. If sandboxing is ever enabled, add
`com.apple.security.network.client = true` (uploads) to the entitlements.

## Live Transcription (on-device)

Settings → General → Live transcription (on by default). While recording, what's said
shows up in a floating panel (opens at each session; `Transcript` in the popover) about
0.5 s after it's spoken, split **Me** (microphone) / **Them** (system tap), and final
segments are appended to `<rec>.live.md` as they come (crash-safe). No network, no model
to ship: Apple's `SpeechTranscriber` (locale from the Transcription language setting,
assets via `AssetInventory`, downloaded once by the system).
- **Audio**: `AudioFileWriter` hands each source, already 48 kHz mono, to a `LiveAudioSink`
  on its queue (inserted restart silence included, so times match the file). The sink only
  yields into bounded `AsyncStream`s (`Constants.Live.maxBufferedChunks`, newest kept):
  live text can drop, the recording never does.
- **Engine**: `reportingOptions: [.volatileResults, .fastResults]` — `.fastResults` is what
  gives ~0.5 s; without it volatile text lags 5–6 s. Volatile results are ~final prefixes
  (≤ 1 % revised), finals cover long stretches (10–30 s), so the panel shows volatile text
  greyed and the file only gets finals. `AnalysisContext.contextualStrings` has no effect
  on `SpeechTranscriber` (measured), so there is no vocabulary setting.
- **Stop**: after the writer finishes, `end()` drains the feeders, finalizes both analyzers,
  waits for the last results; `Constants.Live.finalizationTimeout` (5 s) cancels past it.
  A stop while the model is still downloading cancels the setup instead of waiting.
- **Why Apple** (bench of Sept 2026 on an M4 Pro, 3 × 3 min of real meetings, hand-corrected
  refs): WER ≈ 18 % vs 16 % for Voxtral Realtime 960 ms (best, but GPU-bound: two streams
  fall behind real time), Parakeet v3 23 % (drifts to English, hallucinates in silences),
  Nemotron 3.5 fr 26 %, WhisperKit turbo too slow for two streams. Two Apple streams ran
  30 min with no latency drift, ~1 % CPU in-process (the work runs on the Neural Engine).
- Known gap: with laptop speakers, "them" echoes into the mic and can show up under **Me**.

## Localization

EN (default) + FR via `L10n` (`Bundle.resources`, **not** `Bundle.module`: the SwiftPM
accessor for an executable only looks at the `.app` root and at the compile machine's
absolute build path, so a CI-built release trapped on launch — 0.2.0-beta). Both `.strings` files must carry
identical key sets, and every key referenced from `Localization.swift` must exist —
both enforced by `Tests/L10nParityTests.swift`. Format arguments go through
`L10n.string(_:arguments:)` (never pass a `[CVarArg]` to the variadic overload).

## Logging

`Log.<category>` (`app`, `capture`, `recording`, `teams`, `permissions`, `transcription`,
`settings`, `ui`, `calendar`) are `os.Logger`s with subsystem = bundle identifier. Interpolate
directly and mark what must stay readable in release with `privacy: .public`
(interpolated `String`s are private by default). Filter with
`--predicate 'subsystem == "…" AND category == "teams"'`.

## Code Signing & Distribution (GitHub Actions)

CI (`macos-26`, Xcode 26.5): `lint` (`swift format lint --strict`) and `test`
(`-warnings-as-errors`) on every push to `main`, PR and tag. A `v*` tag additionally
builds the arm64 binary, signs **inside-out without `--deep`** (resource bundle, then the
app with entitlements), creates + signs the DMG, notarizes via notarytool, staples and
creates the GitHub Release (AI-generated notes only); `scripts/release.sh` then updates
the Homebrew cask (`depends_on macos: :tahoe`).

The cask is `Casks/meety.rb` **in this repo** (no separate `homebrew-*` tap repo), so the
tap needs the explicit URL: `brew tap florianchevallier/meeting-recorder
https://github.com/florianchevallier/meeting-recorder`. Keep it `brew style`-clean
(post-install text goes in `caveats`, never `postflight`; `zap` never touches recordings).

```bash
./scripts/release.sh 0.2.0   # full release (tag → CI → cask)
swift format lint --strict --recursive Sources Tests Package.swift   # what CI runs
swift format --in-place --recursive Sources Tests Package.swift      # fix formatting
```

**7 GitHub secrets required** (already configured): `DEVELOPER_ID_CERTIFICATE` (base64 P12),
`CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`, `SIGNING_IDENTITY`, `APPLE_ID`,
`APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.

Release notes are AI-generated (Gemini, OpenAI fallback) from conventional commits
by `.github/scripts/generate-release-notes.py` (`GOOGLE_API_KEY` secret).

`debug_app.sh` signs the debug bundle with the first Apple Development identity found
(or `MEETY_SIGN_IDENTITY`) so TCC grants survive rebuilds; ad-hoc signing resets them.

## Testing

Swift Testing (`@Test`/`#expect`) in `Tests/`, run by CI on every push/PR/tag:
- `RecordingStateTransitionTests` — action × state matrix (incl. stop during starting)
- `CaptureErrorClassifierTests` — OSStatus → policy, FourCC rendering
- `HealthEvaluatorTests`, `CaptureStreamLayoutTests` — pure capture logic
- `AudioFileWriterTests` — real AAC encode of synthetic tap + mic (format, duration, silence)
- `TeamsMonitorTests` — fake source + `ManualClock`: debounce, flicker, reset, stop
- `TeamsMeetingDeciderTests`, `TeamsWindowClassifierTests`
- `PermissionMonitorTests` — fake probes + UUID `UserDefaults` suite
- `OnboardingDecisionTests`, `DefaultsKeyTests`, `IconStateTests`
- `CalendarMatcherTests`, `CalendarAgendaTests` (+ reminder planner), `MeetingMetadataTests`,
  `CalendarMonitorTests` (fake source)
- `FilenameGenerationTests`, `SettingsStoreTests`, `EndpointResolverTests`,
  `MultipartBuilderTests`, `TranscriptionStateMachineTests` (+ progress parsing), `L10nParityTests`
- `TranscriptionHintsTests`, `TranscriptTests` (server JSON shape), `SpeakerLabelerTests`,
  `TranscriptRendererTests`, `VoiceActivityRecorderTests`, `RecordingFilesTests`
- `LiveTranscriptTests` — volatile/final reducer, speaker interleaving, Markdown

Manual smoke checklist after touching Capture: record 2 min with audio playing while
switching output to AirPods and back → one file, `restarting → restarted` in logs, both
voices audible, `<rec>.activity.json` present; Cmd-Q while recording → finalized in < 15 s; `tccutil reset All <bundle>`
then deny the prompt → Verify reports denied and the deep link opens the pane.

## Coding guidelines (Karpathy-inspired)

Source: https://github.com/multica-ai/andrej-karpathy-skills — behavioral
guidelines targeting common LLM coding mistakes (wrong silent assumptions,
overcomplication, non-surgical edits, weak success criteria).

**Tradeoff:** these bias toward caution over speed. For trivial tasks, use
judgment.

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```
