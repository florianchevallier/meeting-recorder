#!/bin/bash

# Script de test pour l'API unifiée ScreenCaptureKit macOS 15+

echo "🚀 Test de l'API unifiée ScreenCaptureKit (macOS 15+)"
echo "=============================================="

# Vérifier la version de macOS
macos_version=$(sw_vers -productVersion)
echo "📱 Version macOS: $macos_version"

# Vérifier si on est sur macOS 15+
if [[ $(echo "$macos_version" | cut -d. -f1) -ge 15 || $(echo "$macos_version" | cut -d. -f1) -eq 15 ]]; then
    echo "✅ macOS 15+ détecté - API unifiée disponible"
else
    echo "⚠️  macOS < 15 détecté - Fallback sur l'ancienne approche"
fi

echo ""
echo "🔧 Compilation du projet..."
if swift build; then
    echo "✅ Compilation réussie"
else
    echo "❌ Erreur de compilation"
    exit 1
fi

echo ""
echo "🎬 Instructions de test:"
echo "1. Lancez l'application avec: ./fix_permissions"
echo "2. Cliquez sur l'icône dans la status bar"
echo "3. Cliquez sur 'Start Recording'"
echo "4. Jouez de la musique ou vidéo (audio système)"
echo "5. Parlez dans le microphone"
echo "6. Cliquez sur 'Stop Recording' après ~10 secondes"
echo ""
echo "📁 Vérifiez les fichiers générés dans ~/Documents/"
echo "   - macOS 15+: meeting_unified_*.mov (format MOV avec audio mixé)"
echo "   - macOS < 15: meeting_*.m4a (format M4A avec audio mixé)"
echo ""
echo "🔍 Pour voir les logs détaillés:"
echo "   log stream --predicate 'subsystem == \"com.meetingrecorder.app\"' --level debug"