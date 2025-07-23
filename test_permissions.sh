#!/bin/bash

# Script pour tester les permissions directement
# Usage: ./test_permissions.sh

echo "🧪 Testing permissions..."

# Fermer l'app existante
pkill -f MeetingRecorder 2>/dev/null || true

# Build et lancer
./build_app.sh debug

echo "🚀 Launching app for permission test..."
open .build/MeetingRecorder.app

# Attendre que l'app démarre
sleep 5

echo "📋 Current logs:"
./view_logs.sh

echo ""
echo "🎯 Now try clicking 'Start Recording' in the app and check for new logs with:"
echo "   tail -f ~/Documents/MeetingRecorder_debug.log"