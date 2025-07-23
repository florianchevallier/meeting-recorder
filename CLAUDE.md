# MeetingRecorder - Application macOS d'Enregistrement Automatique de Réunions

## Vue d'ensemble du projet
Application native macOS dans la status bar qui enregistre automatiquement les réunions en capturant l'audio système et le microphone, avec déclenchement automatique basé sur les événements du calendrier.

## Objectifs MVP
1. Interface dans la status bar avec bouton start/stop manuel
2. Enregistrement simultané audio système + microphone
3. Gestion complète des permissions macOS
4. Intégration calendrier pour déclenchement automatique
5. Sauvegarde des enregistrements avec nommage automatique

## Stack technique
- **Swift/SwiftUI** : Interface utilisateur native
- **ScreenCaptureKit** : Capture audio système (macOS 12.3+)
- **AVAudioEngine** : Enregistrement microphone
- **EventKit** : Intégration calendrier
- **NSStatusItem** : Interface status bar
- **UserNotifications** : Notifications discrètes

## Architecture du projet
```
MeetingRecorder/
├── Sources/
│   ├── MeetingRecorderApp.swift      # Point d'entrée principal
│   ├── StatusBar/
│   │   ├── StatusBarManager.swift    # Gestion status bar ✅ IMPLÉMENTÉ
│   │   └── StatusBarMenu.swift       # Menu déroulant ✅ IMPLÉMENTÉ
│   ├── Audio/
│   │   ├── AudioRecorder.swift       # Logique enregistrement ✅ IMPLÉMENTÉ
│   │   ├── ScreenAudioCapture.swift  # ScreenCaptureKit ✅ IMPLÉMENTÉ
│   │   ├── MicrophoneCapture.swift   # AVAudioEngine ✅ IMPLÉMENTÉ
│   │   └── AudioMixer.swift          # Mélangeur audio temps réel ✅ IMPLÉMENTÉ
│   ├── Calendar/
│   │   ├── CalendarManager.swift     # EventKit integration ⏳ EN ATTENTE
│   │   └── MeetingDetector.swift     # Détection événements ⏳ EN ATTENTE
│   ├── Permissions/
│   │   └── PermissionManager.swift   # Gestion permissions ✅ IMPLÉMENTÉ
│   └── Models/
│       ├── RecordingSession.swift    # Modèle session ✅ IMPLÉMENTÉ
│       └── MeetingEvent.swift        # Modèle événement ✅ IMPLÉMENTÉ
├── Resources/
│   └── Info.plist                    # Permissions macOS ✅ IMPLÉMENTÉ
├── Tests/
│   └── MeetingRecorderTests/
│       └── MeetingRecorderTests.swift ✅ STRUCTURE CRÉÉE
└── Package.swift                     # Configuration SPM ✅ IMPLÉMENTÉ
```

## Permissions requises (Info.plist)
```
NSMicrophoneUsageDescription
Cette application a besoin d'accéder au microphone pour enregistrer vos réunions

NSCalendarsUsageDescription
Cette application accède à votre calendrier pour démarrer automatiquement les enregistrements de réunion

NSScreenRecordingUsageDescription
Cette application a besoin d'enregistrer l'écran pour capturer l'audio système lors des réunions
```

## Commandes de développement
- `swift build` : Compiler le projet
- `swift run` : Lancer l'application en mode debug
- `swift test` : Exécuter les tests unitaires
- `xcodebuild -scheme MeetingRecorder archive` : Build pour distribution

## Règles de développement

### Code Style
- Utiliser Swift moderne avec async/await pour les opérations asynchrones
- SwiftUI pour l'interface utilisateur
- Nommage explicite des variables et fonctions
- Documentation inline pour les méthodes publiques

### Architecture
- Pattern MVVM avec ObservableObject
- Séparation claire des responsabilités par modules
- Gestion centralisée des permissions
- État de l'application géré par un StateManager global

### Sécurité et Permissions
- Demander TOUTES les permissions au premier lancement
- Gestion gracieuse des permissions refusées
- Messages d'erreur clairs et actionables pour l'utilisateur
- Vérification des permissions avant chaque opération critique

## Workflow de développement

### Phase 1 : MVP Status Bar (2-3 semaines)
**Objectif** : Application fonctionnelle dans la status bar avec enregistrement manuel

**Sprint 1** : Infrastructure de base ✅ **TERMINÉ**
- [x] Configuration projet Swift Package Manager
- [x] Interface status bar basique avec NSStatusItem
- [x] Menu déroulant avec boutons Start/Stop
- [x] Icônes et états visuels (idle, recording)

**Sprint 2** : Enregistrement audio ✅ **TERMINÉ**
- [x] Intégration ScreenCaptureKit pour audio système
- [x] Configuration AVAudioEngine pour microphone
- [x] Enregistrement simultané des deux sources avec AudioMixer
- [x] Sauvegarde fichiers audio (format .m4a)

**Sprint 3** : Permissions et stabilité ✅ **TERMINÉ**
- [x] PermissionManager pour toutes les permissions
- [x] Gestion des erreurs et états d'échec
- [x] Interface d'erreur si permissions manquantes
- [x] Tests de base et debugging

### Phase 2 : Intégration Calendrier (1-2 semaines)
**Objectif** : Déclenchement automatique basé sur les événements calendrier

**Sprint 4** : Accès calendrier
- [ ] CalendarManager avec EventKit
- [ ] Détection événements en cours/à venir
- [ ] Filtrage par mots-clés (réunion, meeting, call, etc.)
- [ ] Service background pour surveillance continue

**Sprint 5** : Automatisation
- [ ] Déclenchement automatique 2 minutes avant réunion
- [ ] Notification discrète du début d'enregistrement
- [ ] Nommage automatique fichier (date_heure_titre_reunion.m4a)
- [ ] Gestion conflits (plusieurs réunions simultanées)

### Phase 3 : Fonctionnalités Avancées (optionnel)
- Préférences utilisateur (qualité audio, dossier sauvegarde)
- Interface de gestion des enregistrements
- Export rapide et partage
- Intégration Shortcuts macOS

## Configuration ScreenCaptureKit
```
// Configuration de base pour capture audio
let config = SCStreamConfiguration()
config.capturesAudio = true
config.captureMicrophone = true
config.sampleRate = 48000
config.channelCount = 2
```

## Points d'attention critiques

### Gestion des erreurs
- Toujours vérifier la disponibilité de ScreenCaptureKit (macOS 12.3+)
- Gérer les cas où l'utilisateur révoque les permissions
- Fallback gracieux si l'enregistrement échoue

### Performance
- ScreenCaptureKit peut être gourmand en ressources
- Optimiser la qualité audio vs taille fichier
- Libérer les ressources correctement à l'arrêt

### UX Status Bar
- Icône change d'état (idle → recording → processing)
- Menu contextuel toujours accessible
- Raccourcis clavier pour start/stop (optionnel)

## Tests à effectuer
- [x] Premier lancement avec demande permissions
- [x] Enregistrement manuel avec audio système + micro
- [ ] Déclenchement automatique depuis calendrier
- [x] Gestion permissions refusées
- [x] Qualité audio des fichiers générés
- [ ] Stabilité lors d'enregistrements longs (1h+)

## 🎯 STATUT ACTUEL DU PROJET

### ✅ **PHASE 1 TERMINÉE** - MVP Status Bar Fonctionnel
L'application est **entièrement fonctionnelle** pour l'enregistrement manuel !

#### 🎉 Fonctionnalités Opérationnelles
- **Interface Status Bar** : Icône animée, menu contextuel avec timer
- **Capture Audio Système** : ScreenCaptureKit avec optimisations 2024-2025
- **Capture Microphone** : AVAudioEngine avec input par défaut
- **Mélangeur Temps Réel** : AudioMixer combine les deux sources sans feedback
- **Sauvegarde M4A** : Fichiers haute qualité (48kHz, stéréo, AAC)
- **Gestion Permissions** : Microphone, calendrier, screen recording
- **Nommage Automatique** : `meeting_YYYY-MM-DD_HH-mm-ss.m4a`

#### 🚀 Comment Tester
```bash
# Lancer l'application
swift run

# Cliquer sur l'icône status bar → Start Recording
# Jouer de la musique + parler dans le micro
# Stop Recording → Vérifier ~/Documents/
```

### 🔄 **PHASE 2 EN ATTENTE** - Intégration Calendrier
Les classes de base sont créées mais pas encore connectées au système principal.

#### ⏳ À Implémenter
- Connexion CalendarManager ↔ StatusBarManager
- Auto-déclenchement basé sur les événements
- Notifications système discrètes
- Nommage intelligent avec titre de réunion

## Critères d'acceptation MVP
- ✅ Application visible dans status bar
- ✅ Enregistrement manuel fonctionnel
- ✅ Audio système ET microphone capturés simultanément
- ✅ Fichiers sauvegardés avec nommage cohérent
- ✅ Permissions gérées proprement
- ✅ Pas de crash lors d'utilisation normale

## 🎯 Prochaines Étapes Prioritaires
1. **Connecter le CalendarManager** au StatusBarManager
2. **Implémenter l'auto-déclenchement** basé sur les événements
3. **Ajouter les notifications** système
4. **Tests de stabilité** avec enregistrements longs

## Notes techniques importantes

### Configuration Audio Implémentée
```swift
// Configuration ScreenCaptureKit optimisée
config.capturesAudio = true
config.sampleRate = 48000
config.channelCount = 2
config.excludesCurrentProcessAudio = true
// Vidéo désactivée pour les performances
config.width = 1
config.height = 1
config.minimumFrameInterval = CMTime(seconds: 10, preferredTimescale: 1)
```

### Architecture Audio Pipeline
1. **ScreenAudioCapture** → CMSampleBuffer (audio système)
2. **MicrophoneCapture** → AVAudioPCMBuffer (microphone)
3. **AudioMixer** → Conversion + mélange temps réel
4. **AudioRecorder** → Sauvegarde M4A async

### Compatibilité macOS
- **macOS 12.3+** : ScreenCaptureKit complet
- **macOS 13.0+** : Configuration audio avancée
- **macOS 14.0+** : Gestion permissions calendrier moderne
- **macOS 15.0+** : Support microphone ScreenCaptureKit (non utilisé)

### Permissions Système
- **Microphone** : AVCaptureDevice.requestAccess(for: .audio)
- **Screen Recording** : Nécessaire pour ScreenCaptureKit audio
- **Calendrier** : EventKit avec requestFullAccessToEvents (macOS 14+)

### Performance et Optimisations
- **Audio Quality** : AAC 48kHz stéréo haute qualité
- **Latency** : Buffer size 1024 frames pour réactivité
- **Memory** : Gestion async des buffers, nettoyage automatique
- **CPU** : ScreenCaptureKit hardware-accelerated

### Debugging et Logs
```bash
# Voir les permissions système
tccutil reset Microphone com.meetingrecorder.app
tccutil reset ScreenCapture com.meetingrecorder.app

# Vérifier les fichiers générés
ls -la ~/Documents/meeting_*.m4a
```

L'application compile sans erreur et est prête pour utilisation ! 🎉