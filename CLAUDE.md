# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# MeetingRecorder - macOS Meeting Recording Application

## Project Overview
Native macOS status bar application that automatically records meetings by capturing system audio and microphone, with automatic Teams meeting detection. The application runs entirely from the status bar and produces high-quality M4A files.

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
# View real-time application logs
tail -f ~/Documents/MeetingRecorder_debug.log

# Reset system permissions for testing
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app

# Check generated recording files
ls -la ~/Documents/meeting_*.m4a
```

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
- **macOS 12.3+**: Required for ScreenCaptureKit
- **macOS 13.0+**: Enhanced audio configuration options
- **macOS 14.0+**: Modern permission handling for calendar/accessibility
- **macOS 15.0+**: Unified capture API with direct recording (UnifiedScreenCapture)

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
The application uses a dual-path recording approach:
1. **Legacy path (macOS < 15)**: Separate SystemAudioCapture + MicrophoneCapture → AudioMixer combines → M4A export
2. **Unified path (macOS 15+)**: UnifiedScreenCapture records directly to .mov → converts to M4A

**StatusBarManager coordinates** both approaches transparently based on OS version detection.

### Teams Detection Integration
```swift
// Teams status change handling in StatusBarManager
NotificationCenter.default.addObserver(
    forName: .teamsMeetingStatusChanged,
    object: nil,
    queue: .main
) { [weak self] notification in
    // Auto-recording logic triggered here
    self?.handleTeamsMeetingStatusChange(isActive: isActive)
}
```

## Permission Requirements

The application requires four system permissions, all managed by PermissionManager:

1. **Microphone** (AVFoundation): Voice recording
2. **Screen Recording** (ScreenCaptureKit): System audio capture  
3. **Documents Folder**: File storage for recordings
4. **Accessibility API**: Teams window monitoring for auto-detection

**Permission Flow**: OnboardingManager → PermissionManager → User prompts → StatusBarManager validation

## Key Code Locations

| Function | File:Line | Purpose |
|----------|-----------|---------|
| `startRecording()` | StatusBarManager.swift:198 | Main recording workflow coordinator |
| `mixAudioFiles()` | AudioMixer.swift:6 | Audio mixing and M4A export logic |
| `handleTeamsMeetingStatusChange()` | StatusBarManager.swift:60 | Auto-recording decision logic |
| `checkAllPermissions()` | PermissionManager.swift:20 | Complete permission validation |
| `setupTeamsDetection()` | StatusBarManager.swift:41 | Teams monitoring initialization |

## Application Lifecycle

1. **MeetingRecorderApp.swift**: Entry point, sets up AppDelegate
2. **AppDelegate**: Creates StatusBarManager, handles onboarding check
3. **StatusBarManager**: Initializes all subsystems (audio, Teams detection, permissions)
4. **OnboardingManager**: Manages first-launch permission flow if needed
5. **Runtime**: Status bar interface handles user interactions and auto-recording

## Logging and Debugging

The application uses `Logger.shared` throughout for consistent logging:
- All logs written to `~/Documents/MeetingRecorder_debug.log`
- Structured logging with component prefixes: `[AUDIO_MIXER]`, `[TEAMS]`, `[RECORDING]`
- Real-time log monitoring recommended during development

## Testing Strategy

- **Manual Testing**: Primary validation method using debug logging
- **Permission Testing**: Use tccutil reset commands for repeated testing
- **Recording Validation**: Check output file quality and metadata
- **Teams Detection**: Test with actual Teams meetings and window states

## Common Development Patterns

- **Async/Await**: Used throughout for audio operations and permission requests
- **@MainActor**: UI updates and state management confined to main thread
- **ObservableObject**: StatusBarManager and PermissionManager published state
- **NotificationCenter**: Teams detection events and cross-component communication
- **Error Handling**: Comprehensive with user-friendly messages via localization

## Localization

- **Languages**: English (default), French
- **Location**: `Sources/Resources/[lang].lproj/Localizable.strings`
- **Usage**: `L10n.keyName` pattern throughout codebase
- **Key Areas**: Permission descriptions, error messages, UI labels

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
| **Auto Stop** | Status bar menu | Enabled |
| **Grace Period** | StatusBarManager.swift:26 | 1 second |
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
# View real-time logs
tail -f ~/Documents/MeetingRecorder_debug.log

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