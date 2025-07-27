# 🤝 Contributing Guide - MeetingRecorder

Thank you for your interest in contributing to MeetingRecorder! This guide will help you get started.

## 🚀 Quick Start

### Prerequisites
- **macOS 12.3+** with Xcode 15.0+
- **Swift 5.9+**
- **Git** configured with your GitHub account

### Local Setup

```bash
# 1. Fork the repository on GitHub
# 2. Clone your fork
git clone https://github.com/your-username/meeting-recorder.git
cd meeting-recorder

# 3. Add original repository as upstream remote
git remote add upstream https://github.com/florianchevallier/meeting-recorder.git

# 4. Test everything works
swift build && swift test
```

## 🎯 Types of Contributions

### 🐛 Bug Reports
Use **GitHub Issues** with the bug template:
- **Clear description** of the problem
- **Detailed reproduction steps**
- **Environment**: macOS version, Xcode, Swift
- **Logs** if available (`~/Documents/MeetingRecorder_debug.log`)

### ✨ Feature Requests
- **Use case**: Why is this feature needed?
- **Expected behavior**: How should it work?
- **Alternatives**: Current workarounds

### 🔧 Code Contributions
- **Bug fixes**: Fixing existing issues
- **Features**: New functionality from roadmap
- **Tests**: Improving test coverage
- **Documentation**: Improving README, comments

## 📋 Development Workflow

### 1. Create a Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/my-new-feature
```

### 2. Development

#### Code Structure
- **Audio/**: Audio capture and processing
- **StatusBar/**: Status bar user interface  
- **Permissions/**: macOS permission management
- **Calendar/**: Automatic meeting detection
- **Utils/**: Utilities and logging

#### Code Standards
```swift
// ✅ Good: Explicit naming
class ScreenAudioCapture {
    private let streamConfiguration: SCStreamConfiguration
    
    func startCapturing() async throws {
        // Implementation
    }
}

// ❌ Avoid: Short/ambiguous names
class SAC {
    var config: Any
    func start() { }
}
```

#### Error Handling
```swift
// ✅ Explicit handling with context
enum AudioCaptureError: Error {
    case permissionDenied
    case deviceNotAvailable(String)
    case configurationFailed(underlying: Error)
}

func setupAudioCapture() throws {
    guard hasPermission else {
        throw AudioCaptureError.permissionDenied
    }
    // ...
}
```

### 3. Testing

```bash
# Run all tests
swift test

# Specific tests
swift test --filter AudioMixerTests

# Build and test in release mode
swift build -c release
swift test -c release
```

### 4. Documentation

- **Inline comments** for public methods
- **README** updated if necessary
- **CHANGELOG** for important features

## 🧪 Local Testing

### Functional Tests
1. **First launch**: Permissions requested correctly
2. **Recording**: System audio + microphone captured
3. **Interface**: Responsive status bar, functional timer
4. **Files**: M4A saving with correct naming

### Performance Tests
- **Latency**: <100ms for real-time recording
- **Memory**: No memory leaks during long recordings
- **CPU**: Reasonable usage with ScreenCaptureKit

### Permission Tests
```bash
# Reset permissions for testing
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app

# Restart app and verify flow
./debug_app.sh
```

## 📝 Commit Standards

### Message Format
```
type(scope): short description

More detailed description if necessary.

Fixes #123
```

### Commit Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only
- **style**: Formatting, missing semicolons
- **refactor**: Refactoring without functional change
- **test**: Adding/modifying tests
- **chore**: Maintenance, tools, CI

### Examples
```bash
git commit -m "feat(audio): add real-time audio mixing support"
git commit -m "fix(permissions): handle calendar permission denial gracefully"
git commit -m "docs(readme): update installation instructions"
```

## 🔄 Pull Request Process

### 1. Prepare PR
```bash
# Ensure tests pass
swift build && swift test

# Rebase on main if necessary
git fetch upstream
git rebase upstream/main

# Push to your fork
git push origin feature/my-new-feature
```

### 2. Create Pull Request
- **Descriptive title** following commit conventions
- **Description**: What changes and why?
- **Tests**: How did you test your changes?
- **Screenshots** if UI changes

### 3. Review Process
- **Automated checks**: Build and tests must pass
- **Code review**: At least one approval required
- **Testing**: Test on different macOS versions if possible

## 🎯 Current Priorities

### Phase 2 - Automation
- [ ] **CalendarManager Integration**: Connect to StatusBarManager
- [ ] **Teams Detection**: Process and window monitoring
- [ ] **Auto-trigger**: Automatic start before meetings
- [ ] **Notifications**: Discrete system alerts

### Technical Improvements
- [ ] **Test Coverage**: Increase test coverage
- [ ] **Error Handling**: Improve error management
- [ ] **Performance**: Optimize audio capture
- [ ] **Documentation**: Comment public APIs

## 🆘 Need Help?

### Communication
- **GitHub Issues**: Technical questions, bugs
- **GitHub Discussions**: General questions, ideas
- **Email**: florian@example.com for private questions

### Resources
- **Apple Documentation**: ScreenCaptureKit, AVAudioEngine
- **Swift.org**: Swift language guide
- **Code Examples**: Existing project sources

## 📜 Code of Conduct

- **Respectful**: Kind interactions with everyone
- **Constructive**: Improvement-oriented feedback
- **Inclusive**: Welcoming environment for all
- **Professional**: Clear and courteous communication

---

**Thank you for contributing to MeetingRecorder! 🙏**

Every contribution, small or large, improves the project for the entire community.