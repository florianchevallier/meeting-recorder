#!/bin/bash

# Script pour débugger MeetingRecorder.app
# Usage: ./debug_app.sh

set -e

echo "🐛 Building and debugging MeetingRecorder.app..."
./fix_permissions.sh

# Build en mode debug
./build_app.sh debug

APP_BUNDLE=".build/MeetingRecorder.app"

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

# Attendre un peu que l'app démarre
sleep 2

# Stream les logs système pour notre app
echo "📋 Streaming logs (process: MeetingRecorder)..."
log stream --predicate 'subsystem == "com.meetingrecorder.app" OR process == "MeetingRecorder"' --level debug --style compact 2>/dev/null || {
    echo "⚠️  System log streaming failed, trying alternative method..."
    
    # Méthode alternative: surveiller Console.app logs
    tail -f /var/log/system.log 2>/dev/null | grep -i meetingrecorder || {
        echo "📄 System logs not accessible, showing recent logs:"
        log show --predicate 'process == "MeetingRecorder"' --last 1m --info
    }
}