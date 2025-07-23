#!/bin/bash

# Script pour créer un vrai bundle .app macOS
# Usage: ./build_app.sh

set -e

echo "🔨 Building MeetingRecorder.app bundle..."

# Variables
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="MeetingRecorder"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$APP_BUNDLE"

# Build the Swift executable
BUILD_CONFIG=${1:-release}
echo "📦 Building Swift executable (config: $BUILD_CONFIG)..."
swift build -c $BUILD_CONFIG

# Create app bundle structure
echo "🏗️  Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
echo "📋 Copying executable..."
cp "$BUILD_DIR/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
echo "📄 Copying Info.plist..."
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo file
echo "📝 Creating PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Make executable executable
chmod +x "$MACOS_DIR/$APP_NAME"

cp -r "$APP_BUNDLE" /Applications/

echo "✅ MeetingRecorder.app bundle created at: $APP_BUNDLE"
echo ""
echo "🚀 To run: open /Applications/MeetingRecorder.app"
echo ""
echo "⚠️  Note: First launch may require allowing the app in System Preferences > Privacy & Security"