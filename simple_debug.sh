#!/bin/bash

# Script de debug simple
# Usage: ./simple_debug.sh

echo "🐛 Building and running debug version..."

# Build en mode debug
./build_app.sh debug

# Lancer l'app directement depuis le terminal pour voir les print statements
echo "🚀 Launching app with stdout/stderr capture..."
.build/MeetingRecorder.app/Contents/MacOS/MeetingRecorder