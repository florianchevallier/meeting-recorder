cask "meety" do
  version "0.2.0"
  sha256 "477b0e29e2d47f5836eeafae86ddb24eebb0b0899bcfa79781ed5d8aeb9ccee8"

  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/Meety-#{version}.dmg"
  name "Meety"
  desc "Meeting recorder with Teams detection and system audio capture"
  homepage "https://github.com/florianchevallier/meeting-recorder"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Meety.app"

  uninstall quit: "com.meetingrecorder.meety"

  zap trash: [
    "~/Documents/Meety_debug.log",
    "~/Library/Preferences/com.meetingrecorder.meety.plist",
  ]

  caveats <<~EOS
    Launch Meety from /Applications (open /Applications/Meety.app) and look for
    the 🎤 icon in your menu bar.

    On first launch Meety guides you through 3 permissions:
      1. Microphone - record your voice
      2. System Audio Recording - capture system audio (Teams, Zoom, etc.)
      3. Accessibility - auto-detect Teams meetings

    Recordings are saved to ~/Documents/meeting_*.m4a
    Help: https://github.com/florianchevallier/meeting-recorder#readme
  EOS
end
