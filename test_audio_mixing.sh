#!/bin/bash

echo "🎤 Test de fusion audio - Meeting Recorder"
echo "==========================================="
echo ""

echo "1. Lancer l'application MeetingRecorder"
echo "2. Cliquer sur l'icône dans la barre de statut"
echo "3. Cliquer 'Démarrer' pour commencer l'enregistrement"
echo "4. Jouer de la musique et parler dans le microphone"
echo "5. Cliquer 'Arrêter' après quelques secondes"
echo "6. Vérifier le fichier M4A final dans ~/Documents/"
echo ""

echo "📂 Fichiers actuels dans ~/Documents/ :"
ls -la ~/Documents/meeting_*.m4a 2>/dev/null || echo "Aucun fichier meeting_*.m4a trouvé"
echo ""

echo "🔍 Surveiller les logs en temps réel :"
echo "./view_logs.sh"
echo ""

echo "📱 Lancer l'app :"
echo "swift run" 