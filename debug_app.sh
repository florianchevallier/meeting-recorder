#!/bin/bash

# Script pour débugger MeetingRecorder.app
# Usage: ./debug_app.sh

set -e

echo "🐛 Building and debugging MeetingRecorder.app..."
./fix_permissions.sh

APP_BUNDLE="/Applications/MeetingRecorder.app"

echo ""
echo "🔍 Starting debug session..."
echo "📊 Console logs will appear below"
echo "⌨️  Press Ctrl+C to stop debugging"
echo ""

# Fonction pour nettoyer à la sortie
cleanup() {
    echo ""
    echo "🛑 Stopping debug session..."
    pkill -f "MeetingRecorder" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Lancer l'app en arrière-plan
open "$APP_BUNDLE"

tail -f '/Users/florianchevallier/Documents/MeetingRecorder_debug.log'