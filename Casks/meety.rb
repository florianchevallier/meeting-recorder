cask "meety" do
  version "0.1.18"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"

  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/MeetingRecorder-#{version}.dmg"
  name "Meety"
  desc "Native macOS meeting recorder with Teams detection and system audio capture"
  homepage "https://github.com/florianchevallier/meeting-recorder"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sequoia"

  app "Meety.app"

  postflight do
    puts ""
    puts "🎤 Meety installed successfully!"
    puts ""
    puts "⚠️  SECURITY: First launch requires manual approval"
    puts ""
    puts "📍 METHOD 1 - Right-click (Recommended):"
    puts "   1. Open Applications folder"
    puts "   2. Right-click on Meety.app → 'Open'"
    puts "   3. Click 'Open' in the security dialog"
    puts ""
    puts "📍 METHOD 2 - Security Preferences:"
    puts "   1. Try to open Meety normally (will fail)"
    puts "   2. System Settings → Privacy & Security"
    puts "   3. Click 'Open Anyway' next to blocked app warning"
    puts "   4. Enter your password if prompted"
    puts ""
    puts "💡 TIP: Opening Security Preferences directly:"
    puts "   Run: open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Security'"
    puts ""
    puts "✅ This is only needed once - subsequent launches work normally!"
    puts ""
    puts "🚀 After setup, look for the 🎤 icon in your menu bar"
    puts ""
  end

  uninstall quit: "com.meetingrecorder.meety"

  zap trash: [
    "~/Documents/MeetingRecorder_debug.log",
    "~/Documents/meeting_*.m4a",
    "~/Library/Preferences/com.meetingrecorder.meety.plist",
  ]
end