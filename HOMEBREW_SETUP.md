# Homebrew Tap Setup Guide

This guide explains how to set up and publish your Meety Homebrew tap using your existing GitHub releases in the same repository.

## Overview

The Homebrew tap is configured as a subdirectory (`homebrew-tap/`) in your main project repository. It uses the DMG files from your GitHub releases directly - no separate repository needed!

## 1. Current Setup

✅ **Already Done:**
- Homebrew formula created at `homebrew-tap/Formula/meety.rb`
- Uses DMG from release: `https://github.com/florianchevallier/meeting-recorder/releases/download/v0.1.9/MeetingRecorder-0.1.9.dmg`
- Automatic update script: `homebrew-tap/update_formula.sh`
- Documentation: `homebrew-tap/README.md`
- CI/CD workflows: `homebrew-tap/.github/workflows/tests.yml`

## 2. Commit and Push the Tap

```bash
# Add the homebrew tap files to your main repository
git add homebrew-tap/
git commit -m "feat: add Homebrew tap for Meety"
git push origin main
```

## 3. Test the Formula Locally

```bash
# Test the formula syntax
brew audit --strict homebrew-tap/Formula/meety.rb

# Install locally for testing
brew install --build-from-source homebrew-tap/Formula/meety.rb

# Test the installation
brew test meety

# Test launching
meety

# Uninstall after testing
brew uninstall meety
```

## 4. Usage Instructions for Users

Once committed, users can install Meety with:

```bash
# Option 1: Add tap then install
brew tap florianchevallier/meety https://github.com/florianchevallier/meeting-recorder.git
brew install meety

# Option 2: Direct installation (one command)
brew install florianchevallier/meety/meety

# Launch the app
meety
```

## 5. Update Formula for New Releases

When you create a new release with a new DMG, update the formula:

```bash
# Navigate to tap directory
cd homebrew-tap

# Automatic update with latest release
./update_formula.sh

# Or specify a version
./update_formula.sh v0.2.0

# Commit the changes
git add Formula/meety.rb
git commit -m "chore: update Meety to v0.2.0"
git push
```

The script will:
- Download the new DMG from your GitHub release
- Calculate the SHA256 checksum automatically
- Update the formula with the new version and checksum

## 6. How It Works

### DMG-Based Installation
- **Downloads**: Pre-built DMG from your GitHub releases
- **Installs**: Extracts and copies the app bundle
- **Performance**: Fast installation (no compilation required)
- **Dependencies**: No Xcode or Swift required for users

### Formula Structure
```ruby
class Meety < Formula
  desc "Native macOS meeting recorder with Teams detection"
  homepage "https://github.com/florianchevallier/meeting-recorder"
  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v0.1.9/MeetingRecorder-0.1.9.dmg"
  sha256 "9bb2c4814a5d10c281787f2c42bac3eeee151bc8dae99a446473b3a4fe823a28"
  version "0.1.9"
  license "MIT"
  
  depends_on :macos => :sequoia
  # No build dependencies - uses pre-built binaries!
```

## 7. Maintenance Workflow

### For Each New Release:

1. **Create Release** (you already do this):
   ```bash
   # Your existing release process creates:
   # https://github.com/florianchevallier/meeting-recorder/releases/download/vX.X.X/MeetingRecorder-X.X.X.dmg
   ```

2. **Update Formula**:
   ```bash
   cd homebrew-tap
   ./update_formula.sh
   git add Formula/meety.rb
   git commit -m "chore: update to vX.X.X"
   git push
   ```

3. **Users Update**:
   ```bash
   brew update
   brew upgrade meety
   ```

## 8. Verification

Your formula correctly references:
- ✅ Repository: `https://github.com/florianchevallier/meeting-recorder`
- ✅ Release DMG: `MeetingRecorder-0.1.9.dmg`
- ✅ SHA256 checksum: Validated automatically
- ✅ Version tracking: Follows your existing tags

## 9. Advanced Features

### Cask Alternative (Optional)

If you prefer a more native macOS app experience, you could also create a Cask:

```ruby
# homebrew-tap/Casks/meety.rb
cask "meety" do
  version "0.1.9"
  sha256 "9bb2c4814a5d10c281787f2c42bac3eeee151bc8dae99a446473b3a4fe823a28"
  
  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/MeetingRecorder-#{version}.dmg"
  name "Meety"
  desc "Native macOS meeting recorder with Teams detection"
  homepage "https://github.com/florianchevallier/meeting-recorder"
  
  app "MeetingRecorder.app", target: "Meety.app"
end
```

## 10. Benefits of This Approach

### Single Repository
- ✅ No separate tap repository to maintain
- ✅ Formula and app code in one place
- ✅ Easier to keep in sync
- ✅ Single issue tracker for everything

### Uses Your Existing Releases
- ✅ Leverages your automated release process
- ✅ No additional build infrastructure needed
- ✅ Same DMG files users can download manually
- ✅ Consistent installation experience

### Fast User Installation
- ✅ No compilation required
- ✅ No Xcode dependency
- ✅ Quick download and install
- ✅ Works on any macOS 15+ system

## 11. Troubleshooting

### Formula fails to install
```bash
# Check if DMG URL is accessible
curl -I https://github.com/florianchevallier/meeting-recorder/releases/download/v0.1.9/MeetingRecorder-0.1.9.dmg

# Verify SHA256 matches
curl -sL https://github.com/florianchevallier/meeting-recorder/releases/download/v0.1.9/MeetingRecorder-0.1.9.dmg | shasum -a 256
```

### App doesn't launch
- Users need to right-click and "Open" for unsigned apps
- Check that all required permissions are granted
- Verify the app bundle structure is correct

### Testing Commands
```bash
# Test formula locally
brew install --build-from-source --verbose homebrew-tap/Formula/meety.rb

# Debug installation issues
brew install --build-from-source --debug homebrew-tap/Formula/meety.rb

# Check formula style
brew audit homebrew-tap/Formula/meety.rb

# List installed files
brew list meety
```

## Next Steps

1. ✅ Commit the tap to your repository
2. ✅ Test the installation locally
3. ✅ Share installation instructions with users
4. 🔄 Use `update_formula.sh` for future releases