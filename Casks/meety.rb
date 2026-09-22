cask "meety" do
  version "0.2.0"
  sha256 "477b0e29e2d47f5836eeafae86ddb24eebb0b0899bcfa79781ed5d8aeb9ccee8"

  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/Meety-#{version}.dmg"
  name "Meety"
  desc "Native macOS meeting recorder with Teams detection and system audio capture"
  homepage "https://github.com/florianchevallier/meeting-recorder"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe
  depends_on arch: :arm64

  app "Meety.app"

  postflight do
    puts ""
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "🎉 Meety installed successfully!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts ""
    puts "✅ This app is signed and notarized by Apple - no security warnings!"
    puts ""
    puts "🚀 To launch Meety:"
    puts "   • Open Applications folder"
    puts "   • Double-click Meety.app (or run: open /Applications/Meety.app)"
    puts "   • Look for the 🎤 icon in your menu bar"
    puts ""
    puts "📋 First Launch Setup:"
    puts "   Meety will guide you through granting 3 permissions:"
    puts "   1. 🎤 Microphone - Record your voice"
    puts "   2. 🔊 System Audio Recording - Capture system audio (Teams, Zoom, etc.)"
    puts "   3. ♿ Accessibility - Auto-detect Teams meetings"
    puts ""
    puts "💡 All recordings are saved to: ~/Documents/meeting_*.m4a"
    puts ""
    puts "📚 Need help? Check the README:"
    puts "   https://github.com/florianchevallier/meeting-recorder#readme"
    puts ""
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts ""
  end

  uninstall quit: "com.meetingrecorder.meety"

  zap trash: [
    "~/Documents/Meety_debug.log",
    "~/Documents/meeting_*.m4a",
    "~/Library/Preferences/com.meetingrecorder.meety.plist",
  ]
end