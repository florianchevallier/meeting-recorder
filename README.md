# 🎤 MeetingRecorder

> Native macOS application for automatic meeting recording with Teams detection and system audio + microphone capture.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2012.3+-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🚀 Features

### ✅ MVP Ready
- **Status Bar Interface**: Animated icon with real-time timer
- **System Audio Capture**: ScreenCaptureKit for application audio
- **Microphone Capture**: High-quality AVAudioEngine recording
- **Real-time Audio Mixing**: Combines both sources without feedback
- **M4A Export**: Optimized AAC 48kHz stereo format
- **Permission Management**: Microphone, screen recording, calendar
- **Automatic Naming**: `meeting_YYYY-MM-DD_HH-mm-ss.m4a`

### 🔄 In Development
- **Teams Detection**: Auto-trigger based on process monitoring
- **Calendar Integration**: Automatic start before meetings
- **Notifications**: Discrete alerts for recording start/stop

## 📋 Requirements

- **macOS 12.3+** (ScreenCaptureKit required)
- **Swift 5.9+**
- **Xcode 15.0+** (for development)

## 🛠 Installation

### From Source

```bash
# Clone repository
git clone https://github.com/florianchevallier/meeting-recorder.git
cd meeting-recorder

# Build and run
swift build
swift run MeetingRecorder
```

### Build for Distribution

```bash
# Create app bundle
./debug_app.sh

# App will be available at .build/MeetingRecorder.app
open .build/MeetingRecorder.app
```

## 🎯 Usage

1. **First Launch**: App requests necessary permissions
2. **Status Bar Interface**: Click the 🎤 icon in the status bar
3. **Manual Recording**: 
   - "Start Recording" to begin
   - "Stop Recording" to finish
4. **Files**: Automatically saved to `~/Documents/`

### Required Permissions

The application automatically requests:
- **🎤 Microphone**: Capture your voice
- **📺 Screen Recording**: Capture system audio (Teams, Zoom, etc.)
- **📅 Calendar**: Automatic meeting detection (optional)

## 📁 Architecture

```
Sources/
├── MeetingRecorderApp.swift          # Main entry point
├── Audio/
│   ├── AudioMixer.swift              # Real-time mixer ✅
│   ├── MicrophoneCapture.swift       # AVAudioEngine ✅
│   ├── SystemAudioCapture.swift      # ScreenCaptureKit ✅
│   └── UnifiedScreenCapture.swift    # Unified capture ✅
├── StatusBar/
│   ├── StatusBarManager.swift        # Status bar management ✅
│   └── StatusBarMenu.swift           # User interface ✅
├── Calendar/
│   └── TeamsDetector.swift           # Teams detection 🔄
├── Permissions/
│   └── PermissionManager.swift       # Permission management ✅
├── Onboarding/
│   ├── OnboardingManager.swift       # First launch flow ✅
│   ├── OnboardingView.swift          # Onboarding interface ✅
│   └── OnboardingViewModel.swift     # Onboarding logic ✅
└── Utils/
    └── Logger.swift                  # Logging system ✅
```

## 🔧 Technical Configuration

### Audio Pipeline
- **Sample Rate**: 48kHz
- **Channels**: Stereo (2 channels)
- **Format**: AAC in M4A container
- **Latency**: <100ms for real-time recording

### macOS Compatibility
- **macOS 12.3+**: Full ScreenCaptureKit support
- **macOS 13.0+**: Advanced audio configuration
- **macOS 14.0+**: Modern calendar permissions

## 🧪 Testing & Debug

```bash
# Run tests
swift test

# Debug logs
tail -f ~/Documents/MeetingRecorder_debug.log

# Reset permissions
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app
```

## 🛣 Roadmap

### Phase 2 - Automation (In Progress)
- [ ] CalendarManager ↔ StatusBarManager integration
- [ ] Auto-trigger 2 minutes before meetings
- [ ] Discrete system notifications
- [ ] Smart naming with meeting titles

### Phase 3 - Advanced Features
- [ ] User preferences (quality, folder)
- [ ] Recording management interface
- [ ] Quick export and sharing
- [ ] macOS Shortcuts integration

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Local Development

```bash
# Fork the repository
git clone https://github.com/your-username/meeting-recorder.git

# Create feature branch
git checkout -b feature/my-new-feature

# Develop and test
swift build && swift test

# Commit and push
git commit -m "feat: add my new feature"
git push origin feature/my-new-feature
```

## 📝 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **Apple** for ScreenCaptureKit and macOS frameworks
- **Swift Community** for resources and examples
- **Contributors** who improve this project

---

**⭐ If this project helps you, don't hesitate to give it a star!** 