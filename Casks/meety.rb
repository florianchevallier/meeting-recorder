cask "meety" do
  version "0.1.23"
  sha256 "2e0394b53d905b63f0cdd5b9add3c89f7840bd03e8e10115b5a092711c4df430"

  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/Meety-#{version}.dmg"
  name "Meety"
  desc "Native macOS meeting recorder with Teams detection and system audio capture"
  homepage "https://github.com/florianchevallier/meeting-recorder"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

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
    puts "   Meety will guide you through granting 4 permissions:"
    puts "   1. 🎤 Microphone - Record your voice"
    puts "   2. 📺 Screen Recording - Capture system audio (Teams, Zoom, etc.)"
    puts "   3. 📁 Documents - Save recordings"
    puts "   4. ♿ Accessibility - Auto-detect Teams meetings"
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