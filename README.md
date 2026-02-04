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

### Option 1: Homebrew (Recommended) 🍺

The easiest way to install Meety on macOS:

```bash
# Add the Meety tap
brew tap florianchevallier/meety

# Install Meety
brew install --cask meety

# Launch Meety
open /Applications/Meety.app
```

**That's it!** Meety is now installed and ready to use. Look for the 🎤 icon in your menu bar.

#### Homebrew Commands

```bash
# Update to the latest version
brew upgrade --cask meety

# Uninstall
brew uninstall --cask meety

# Reinstall (if needed)
brew reinstall --cask meety
```

### Option 2: Direct Download

**Download the latest release** from [GitHub Releases](https://github.com/florianchevallier/meeting-recorder/releases/latest)

1. Download `Meety-X.X.X.dmg`
2. Double-click to mount the DMG
3. Drag `Meety.app` to your Applications folder
4. Launch the app (no security warnings - fully signed and notarized!)
5. Grant permissions when requested

✅ **No "right-click → Open" needed** - the app is notarized by Apple!

### For Developers

```bash
# Clone repository
git clone https://github.com/florianchevallier/meeting-recorder.git
cd meeting-recorder

# Build and run locally
swift build
./.build/debug/MeetingRecorder  # IMPORTANT: Use direct executable, not swift run

# Create a local app bundle for testing
./debug_app.sh

# App will be available at .build/MeetingRecorder.app
open .build/MeetingRecorder.app
```

## 🎯 Usage

### First Launch Setup

When you launch Meety for the first time, it will guide you through granting the necessary permissions:

1. **Microphone** 🎤 - To record your voice during meetings
2. **Screen Recording** 📺 - To capture system audio (Teams, Zoom, etc.)
3. **Documents Folder** 📁 - To save your recordings
4. **Accessibility** ♿ - To detect Teams meetings automatically

**Note**: All permissions can be granted through the onboarding flow. If you skip any, you can grant them later in **System Settings → Privacy & Security**.

### Daily Usage

1. **Status Bar Interface**: Click the 🎤 icon in the menu bar
2. **Manual Recording**: 
   - Click "Start Recording" to begin
   - Click "Stop Recording" to finish
3. **Auto Recording**: Enable in settings to automatically record Teams meetings
4. **Files**: Recordings are saved to `~/Documents/meeting_YYYY-MM-DD_HH-mm-ss.m4a`

### Troubleshooting Permissions

If recording doesn't work, check your permissions:

```bash
# Open System Settings directly to Privacy & Security
open "x-apple.systempreferences:com.apple.preference.security?Privacy"
```

Then verify that Meety has access to:
- **Privacy → Microphone** ✅
- **Privacy → Screen Recording** ✅
- **Privacy → Files and Folders → Documents Folder** ✅
- **Privacy → Accessibility** ✅ (for Teams detection)

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

## ❓ FAQ

### How do I know if Meety is recording?

Look for the 🎤 icon in your menu bar. When recording:
- The icon animates with a red dot
- A timer shows the recording duration
- Click the icon to see recording status

### Where are my recordings saved?

All recordings are saved to your **Documents folder** with automatic naming:
```
~/Documents/meeting_2026-02-04_14-30-00.m4a
```

### Can I use Meety with Zoom, Google Meet, etc.?

Yes! Meety captures **all system audio**, so it works with:
- Microsoft Teams
- Zoom
- Google Meet
- Slack Huddles
- Any other video conferencing app

### Is my data private?

**100% private!** Meety:
- ✅ Stores all recordings **locally** on your Mac
- ✅ **Never uploads** anything to the cloud
- ✅ **No analytics** or tracking
- ✅ Open source - you can verify the code

### How do I uninstall Meety?

**If installed via Homebrew:**
```bash
brew uninstall --cask meety
```

**If installed manually:**
1. Quit Meety from the menu bar
2. Delete `/Applications/Meety.app`
3. (Optional) Remove recordings from `~/Documents/meeting_*.m4a`

### The app won't open / shows security warning

This shouldn't happen with Homebrew installation, but if it does:
1. Right-click on `Meety.app` in Applications
2. Select "Open"
3. Click "Open" in the dialog
4. This is only needed once

## 🧪 Testing & Debug

```bash
# View real-time logs
tail -f ~/Documents/Meety_debug.log

# Reset permissions (for testing)
tccutil reset Microphone com.meetingrecorder.meety
tccutil reset ScreenCapture com.meetingrecorder.meety

# Check if Meety is running
ps aux | grep Meety
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