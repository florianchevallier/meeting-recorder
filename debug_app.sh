#!/bin/bash

# Build, bundle and launch Meety in debug mode with its own identity.
# Usage: ./debug_app.sh [build_config]
# build_config: debug|release (default: debug)
#
# SAFETY: this script NEVER touches the production app (/Applications/Meety.app)
# and NEVER resets system permissions (that was the old destructive behavior).
# It only manages its own bundle: /Applications/MeetyDebug.app (debug) or
# /Applications/Meety.app (release, explicit opt-in).

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="MeetingRecorder"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUILD_CONFIG="${1:-debug}"

# Bundle ID based on build config
if [ "$BUILD_CONFIG" = "debug" ]; then
    BUNDLE_ID="com.meetingrecorder.meety.debug"
    APP_DISPLAY_NAME="Meety Debug"
    APP_FILE_NAME="MeetyDebug.app"
else
    BUNDLE_ID="com.meetingrecorder.meety"
    APP_DISPLAY_NAME="Meety"
    APP_FILE_NAME="Meety.app"
fi
ARCH=$(uname -m)
BUILD_PATH="$BUILD_DIR/$ARCH-apple-macosx/$BUILD_CONFIG"

echo "🐛 Building Meety.app (config: $BUILD_CONFIG, bundle ID: $BUNDLE_ID)..."

# 1. Stop only OUR app instance (never the production Meety unless release mode)
echo "🗑️  Cleaning previous install..."
if [ "$BUILD_CONFIG" = "debug" ]; then
    pkill -f "MeetyDebug" 2>/dev/null || true
else
    pkill -x "Meety" 2>/dev/null || true
fi
rm -rf "/Applications/$APP_FILE_NAME"
rm -rf "$APP_BUNDLE"

# 2. Build Swift executable
echo "📦 Building Swift executable..."
swift build -c "$BUILD_CONFIG"

# 3. Create bundle structure
echo "🏗️  Creating app bundle..."
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"

echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy resource bundle (localization, icons)
if [ -d "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle" ]; then
    echo "📦 Copying resources bundle..."
    cp -R "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle" "$RESOURCES_DIR/"

    if [ -f "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle/AppIcon.icns" ]; then
        cp "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle/AppIcon.icns" "$RESOURCES_DIR/"
    else
        echo "⚠️  Warning: AppIcon.icns not found in bundle!"
    fi
else
    echo "⚠️  Warning: Resources bundle not found at $BUILD_PATH!"
fi

# 4. Install to Applications
echo "📦 Installing to /Applications/$APP_FILE_NAME..."
mv "$APP_BUNDLE" "/Applications/$APP_FILE_NAME"

# 5. Launch via `open` — critical for TCC: a bundle launched this way gets its
# OWN entry in System Settings privacy panes (a bare binary launched from a
# terminal is attributed to the terminal instead and never appears).
echo "🚀 Launching app..."
open "/Applications/$APP_FILE_NAME"

echo ""
echo "✅ $APP_DISPLAY_NAME installed and launched"
echo "📋 On first launch, grant the 4 permissions — the app appears as '$APP_DISPLAY_NAME'"
echo "    in System Settings → Privacy & Security."
echo ""
echo "📖 Streaming logs (subsystem: $BUNDLE_ID) — Ctrl+C to stop watching (the app keeps running)"
echo ""

log stream --predicate "subsystem == '$BUNDLE_ID'" --level debug
