#!/bin/bash

# Script pour nettoyer les permissions corrompues et reset proprement
# Gère tous les bundle IDs utilisés par l'application :
#   - Production:  com.meetingrecorder.meety
#   - Development: com.meetingrecorder.dev
#   - Debug mode:  com.meetingrecorder.meety.debug
#   - Obsolète:    com.meetingrecorder.app (ancien nom)

echo "🔧 Nettoyage complet des permissions MeetingRecorder..."

# 1. Nettoyer les ANCIENNES permissions (compatibilité)
echo "🗑️  Suppression des anciennes permissions (obsolète)..."
sudo tccutil reset Microphone com.meetingrecorder.app 2>/dev/null || true
sudo tccutil reset ScreenCapture com.meetingrecorder.app 2>/dev/null || true
sudo tccutil reset Accessibility com.meetingrecorder.app 2>/dev/null || true

# 2. Nettoyer les permissions PRODUCTION
echo "🗑️  Reset des permissions production..."
sudo tccutil reset Microphone com.meetingrecorder.meety 2>/dev/null || true
sudo tccutil reset ScreenCapture com.meetingrecorder.meety 2>/dev/null || true
sudo tccutil reset Accessibility com.meetingrecorder.meety 2>/dev/null || true

# 3. Nettoyer les permissions DEVELOPMENT
echo "🗑️  Reset des permissions development..."
sudo tccutil reset Microphone com.meetingrecorder.dev 2>/dev/null || true
sudo tccutil reset ScreenCapture com.meetingrecorder.dev 2>/dev/null || true
sudo tccutil reset Accessibility com.meetingrecorder.dev 2>/dev/null || true

# 4. Nettoyer les permissions DEBUG
echo "🗑️  Reset des permissions debug..."
sudo tccutil reset Microphone com.meetingrecorder.meety.debug 2>/dev/null || true
sudo tccutil reset ScreenCapture com.meetingrecorder.meety.debug 2>/dev/null || true
sudo tccutil reset Accessibility com.meetingrecorder.meety.debug 2>/dev/null || true

# 5. Nettoyer les préférences
echo "🔄 Suppression des préférences..."
defaults delete com.meetingrecorder.app 2>/dev/null || true
defaults delete com.meetingrecorder.meety 2>/dev/null || true
defaults delete com.meetingrecorder.dev 2>/dev/null || true
defaults delete com.meetingrecorder.meety.debug 2>/dev/null || true

# 6. Killer tous les processus
echo "🛑 Arrêt de tous les processus MeetingRecorder..."
pkill -f MeetingRecorder 2>/dev/null || true
pkill -f Meety 2>/dev/null || true

# 7. Supprimer l'app des Applications
echo "🗑️  Suppression app des Applications..."
rm -rf /Applications/MeetingRecorder.app 2>/dev/null || true
rm -rf /Applications/Meety.app 2>/dev/null || true
rm -rf /Applications/MeetyDebug.app 2>/dev/null || true

echo ""
echo "✅ Nettoyage terminé !"
echo ""
echo "🎯 ÉTAPES SUIVANTES :"
echo "1. ./debug_app.sh pour rebuild et relancer"
echo "2. Accorder les permissions DANS L'ORDRE :"
echo "   - Microphone ✅"
echo "   - Screen Recording ✅" 
echo "   - Accessibility ✅"
echo ""
echo "⚠️  IMPORTANT : Bien vérifier que l'app apparaît avec le nom 'Meety'"
echo "    dans Préférences Système > Confidentialité et sécurité"