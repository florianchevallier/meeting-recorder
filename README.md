***

# MeetingRecorder (Meety)

> Native macOS application for meeting recording. Captures system audio and microphone input simultaneously.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2012.3+-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

### Current Functionality
- **Menu Bar Application**: Runs in the background with a visual status indicator.
- **Dual Audio Capture**: Records system output (Teams, Zoom, etc.) and microphone input.
- **Audio Mixing**: Combines sources in real-time without echo or feedback.
- **Export Format**: Saves files as high-quality AAC `.m4a`.
- **Automatic Naming**: Files are saved with the current date and time.

### In Development
- **Teams Detection**: Automatic recording triggers when Teams launches.
- **Calendar Integration**: Scheduled recording based on calendar events.
- **System Notifications**: Alerts for recording status changes.

## Requirements

- **macOS 12.3** or later (Required for ScreenCaptureKit).
- **Swift 5.9** (For building from source).

## Installation

### Option 1: Homebrew (Recommended)

Run the following commands in Terminal:

```bash
brew tap florianchevallier/meety
brew install --cask meety
```

### Option 2: Manual Download

1. Download the latest release from the [GitHub Releases page](https://github.com/florianchevallier/meeting-recorder/releases/latest).
2. Open the disk image (`.dmg`) and drag the application to your Applications folder.
3. Open the application. It is notarized by Apple, so no security overrides are required.

## Usage

### Initial Setup
Upon first launch, the application requires specific permissions to function:

1.  **Microphone**: To record your voice.
2.  **Screen Recording**: Required to capture audio from other applications via ScreenCaptureKit. Video is not recorded.
3.  **Documents Folder**: To save the audio files.

If permissions are denied during setup, enable them later in **System Settings > Privacy & Security**.

### Recording
1.  Click the application icon in the menu bar.
2.  Select **Start Recording**.
3.  To finish, select **Stop Recording**.
4.  The file is automatically saved to your Documents folder.

## Frequently Asked Questions

**How do I verify recording status?**
The menu bar icon displays a red indicator and a timer while recording is active.

**Where are recordings stored?**
Files are saved in the `~/Documents` folder with the naming convention `meeting_YYYY-MM-DD...m4a`.

**Does this support Zoom/Google Meet?**
Yes. The application captures system-wide audio, making it compatible with any conferencing software.

**Is data private?**
Yes. All processing occurs locally on the device. No data is uploaded to the cloud or collected for analytics.

## Development

To build the project locally:

```bash
git clone https://github.com/florianchevallier/meeting-recorder.git
cd meeting-recorder

# Build and run
swift build
./.build/debug/MeetingRecorder
```

### Architecture Overview
- **Audio/**: Handles AVAudioEngine and ScreenCaptureKit integration.
- **StatusBar/**: Manages the menu bar interface.
- **Calendar/**: Logic for meeting detection (WIP).
- **Permissions/**: Handles system permission requests.

## Contributing

Contributions are welcome. Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.