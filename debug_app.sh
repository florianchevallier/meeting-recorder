#!/bin/bash

# Script pour débugger MeetingRecorder.app avec reset complet des permissions
# Usage: ./debug_app.sh [build_config]
# build_config: debug|release (default: release)

set -e

# Variables
LOG_FILE="$HOME/Documents/MeetingRecorder_debug.log"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="MeetingRecorder"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUILD_CONFIG="${1:-release}"
ARCH=$(uname -m)
BUILD_PATH="$BUILD_DIR/$ARCH-apple-macosx/$BUILD_CONFIG"

echo "🐛 Building and debugging MeetingRecorder.app (config: $BUILD_CONFIG)..."

# 1. Désinstallation propre
echo "🗑️  Uninstalling existing app..."
pkill -f MeetingRecorder 2>/dev/null || true
rm -rf /Applications/MeetingRecorder.app
rm -rf "$BUILD_DIR/$APP_NAME.app"

# 2. Reset complet des permissions
echo "🗑️  Resetting all permissions..."
tccutil reset Microphone com.meetingrecorder.app 2>/dev/null || true
tccutil reset ScreenCapture com.meetingrecorder.app 2>/dev/null || true
tccutil reset Accessibility com.meetingrecorder.app 2>/dev/null || true
tccutil reset SystemPolicyDocumentsFolder com.meetingrecorder.app 2>/dev/null || true
tccutil reset SystemPolicyDownloadsFolder com.meetingrecorder.app 2>/dev/null || true
tccutil reset SystemPolicyDesktopFolder com.meetingrecorder.app 2>/dev/null || true

# Reset état onboarding et préférences
echo "🔄 Resetting app preferences..."
defaults delete com.meetingrecorder.app hasCompletedOnboarding 2>/dev/null || true
defaults delete com.meetingrecorder.app 2>/dev/null || true

# 3. Build app bundle
echo "🔨 Building fresh app bundle..."

# Clean build (déjà fait dans l'étape 1)
# rm -rf "$APP_BUNDLE"

# Build Swift executable
echo "📦 Building Swift executable..."
swift build -c "$BUILD_CONFIG"

# Create bundle structure
echo "🏗️  Creating app bundle..."
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy files
cp "$BUILD_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy resource bundle for localization
if [ -d "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle" ]; then
    echo "📦 Copying localization bundle..."
    cp -R "$BUILD_PATH/MeetingRecorder_MeetingRecorder.bundle" "$RESOURCES_DIR/"
else
    echo "⚠️  Warning: Localization bundle not found at $BUILD_PATH!"
    echo "Available files:"
    ls -la "$BUILD_PATH/" 2>/dev/null || echo "Path doesn't exist"
fi

# 4. Install to Applications
echo "📦 Installing to /Applications..."
mv "$APP_BUNDLE" /Applications/

echo "✅ Installation complete!"
echo "💡 App installed at: /Applications/MeetingRecorder.app"

# 5. Lancer session de debug
echo ""
echo "🔍 Starting debug session..."
echo "📊 Console logs: $LOG_FILE"
echo "⌨️  Press Ctrl+C to stop debugging"
echo ""

# Fonction pour nettoyer à la sortie
cleanup() {
    echo ""
    echo "🛑 Stopping debug session..."
    pkill -f "MeetingRecorder" 2>/dev/null || true
    echo "🚀 To restart: open /Applications/MeetingRecorder.app"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Créer le fichier de log s'il n'existe pas
touch "$LOG_FILE"

# Lancer l'app
echo "🚀 Launching app..."
open "/Applications/MeetingRecorder.app"

# Attendre que l'app démarre
sleep 2

# Suivre les logs
echo "📖 Following logs from: $LOG_FILE"
tail -f "$LOG_FILE" 2>/dev/null || {
    echo "⚠️  Log file not found. App may not be logging yet."
    echo "💡 Try using the app and check back."
    read -p "Press Enter to exit..."
}