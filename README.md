# 🎤 Microphone Recorder

Un enregistreur audio ultra simple pour macOS qui capture uniquement le microphone.

## Fonctionnalités

- ✅ Enregistrement audio du microphone
- ✅ Interface dans la barre de statut
- ✅ Bouton start/stop simple
- ✅ Affichage de la durée d'enregistrement
- ✅ Logs détaillés
- ✅ Gestion des permissions automatique

## Utilisation

1. **Lancer l'app** : `./build_app.sh && open .build/MeetingRecorder.app`
2. **Cliquer sur l'icône** dans la barre de statut
3. **Cliquer "Démarrer"** pour commencer l'enregistrement
4. **Cliquer "Arrêter"** pour terminer l'enregistrement

## Fichiers audio

Les enregistrements sont sauvegardés dans `~/Documents/` au format WAV avec un nom incluant un timestamp.

## Logs

Voir les logs avec : `./view_logs.sh`

## Structure simplifiée

```
Sources/
├── MeetingRecorderApp.swift          # Point d'entrée
├── Audio/
│   └── MicrophoneCapture.swift       # Enregistrement micro
├── StatusBar/
│   ├── StatusBarManager.swift        # Gestion barre de statut
│   └── StatusBarMenu.swift           # Interface utilisateur
├── Permissions/
│   └── PermissionManager.swift       # Permissions microphone
└── Utils/
    └── Logger.swift                  # Système de logs
```

## Permissions requises

- **Microphone** : Pour enregistrer l'audio

L'app demande automatiquement les permissions au premier lancement. 