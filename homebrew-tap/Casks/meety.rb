cask "meety" do
  version "0.1.9"
  sha256 "9bb2c4814a5d10c281787f2c42bac3eeee151bc8dae99a446473b3a4fe823a28"

  url "https://github.com/florianchevallier/meeting-recorder/releases/download/v#{version}/MeetingRecorder-#{version}.dmg"
  name "Meety"
  desc "Native macOS meeting recorder with Teams detection and system audio capture"
  homepage "https://github.com/florianchevallier/meeting-recorder"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sequoia"

  app "MeetingRecorder.app", target: "Meety.app"

  uninstall quit: "com.meetingrecorder.meety"

  zap trash: [
    "~/Documents/MeetingRecorder_debug.log",
    "~/Documents/meeting_*.m4a",
    "~/Library/Preferences/com.meetingrecorder.meety.plist",
  ]
end