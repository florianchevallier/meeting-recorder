#!/bin/bash

# Script pour fixer définitivement le problème de permissions
# Usage: ./fix_permissions.sh

echo "🔧 Fixing permissions issue..."

# 1. Kill existing app
pkill -f MeetingRecorder 2>/dev/null || true

# 2. Reset all permissions cleanly
echo "🗑️  Resetting all permissions..."
tccutil reset Microphone com.meetingrecorder.app 2>/dev/null || true
tccutil reset ScreenCapture com.meetingrecorder.app 2>/dev/null || true
tccutil reset Calendar com.meetingrecorder.app 2>/dev/null || true

# 3. Build fresh copy
echo "🔨 Building fresh app..."
./build_app.sh debug > /dev/null 2>&1

# 4. Install to stable location
echo "📦 Installing to Applications..."
rm -rf /Applications/MeetingRecorder.app
cp -r .build/MeetingRecorder.app /Applications/

echo "✅ Done! Now:"
echo "1. Launch: open /Applications/MeetingRecorder.app"
echo "2. Grant ALL permissions when asked (microphone, screen recording, calendar)"
echo "3. Try recording - it should work!"
echo ""
echo "💡 The app is now in /Applications so permissions should stick better."