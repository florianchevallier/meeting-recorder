# Meety

> Meety est une application macOS native qui enregistre vos réunions en capturant simultanément l'audio système et votre microphone. Simple, efficace, et entièrement locale.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0+-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Pourquoi Meety ?

J'avais besoin d'une solution fiable pour enregistrer mes réunions Teams sans jongler entre plusieurs applications. Meety fonctionne discrètement depuis votre barre de menu, capture l'audio système (Teams, Zoom, Meet) et votre microphone en même temps, puis exporte un fichier M4A de qualité.

L'application mixe les deux sources audio en temps réel sans écho ni feedback. Vous obtenez un enregistrement propre, automatiquement nommé avec la date et l'heure, sauvegardé dans votre dossier Documents.

## Fonctionnalités principales

L'application détecte automatiquement quand vous rejoignez une réunion Teams et peut démarrer l'enregistrement sans intervention. L'audio est exporté en AAC 48kHz stéréo, offrant un bon équilibre entre qualité et taille de fichier.

Sur macOS 15 et versions ultérieures, Meety utilise la version optimisée de ScreenCaptureKit avec un système de récupération automatique. Si votre Mac se met en veille pendant un enregistrement, l'application tente de reprendre automatiquement au réveil. Ce système de récupération a demandé beaucoup de travail mais il s'avère précieux pour les longues réunions.

Les fichiers sont nommés automatiquement selon le format `meeting_YYYY-MM-DD_HH-mm-ss.m4a` et sauvegardés directement dans votre dossier Documents. L'interface dans la barre de menu affiche un indicateur rouge et un timer pendant l'enregistrement, rendant le statut très visible.

## À venir

Plusieurs améliorations sont prévues : intégration avec le calendrier pour préparer automatiquement les enregistrements planifiés, notifications discrètes pour les changements de statut, et des préférences avancées permettant de personnaliser la qualité audio et le dossier de destination.

## Configuration requise

Meety nécessite macOS 14.0 minimum. Cette version est requise pour bénéficier des fonctionnalités optimisées de ScreenCaptureKit. L'application est distribuée sous forme de binaire universel, compatible avec les Mac Apple Silicon (M1, M2, M3) et Intel.

Pour compiler depuis les sources, Swift 5.9 ou ultérieur est nécessaire. Cela dit, pour un usage standard, l'installation de la version précompilée est recommandée.

## Installation

### Via Homebrew (recommandé)

Homebrew simplifie l'installation et les mises à jour futures :

```bash
brew tap florianchevallier/meety
brew install --cask meety
```

Une fois installée, lancez l'application avec `open /Applications/Meety.app` ou depuis votre dossier Applications.

### Téléchargement direct

Téléchargez le dernier DMG depuis la [page des releases GitHub](https://github.com/florianchevallier/meeting-recorder/releases/latest). Ouvrez le fichier, glissez Meety.app dans votre dossier Applications, et lancez l'application.

L'application est signée et notarisée par Apple, vous ne rencontrerez donc aucun avertissement de sécurité au premier lancement.

## Mise à jour

### Installation Homebrew

Pour mettre à jour vers la dernière version :

```bash
brew update
brew upgrade --cask meety
```

Homebrew vérifie et installe automatiquement les nouvelles versions disponibles.

### Installation manuelle

Retournez sur [GitHub Releases](https://github.com/florianchevallier/meeting-recorder/releases/latest), téléchargez le nouveau DMG, et remplacez l'application existante dans votre dossier Applications. Relancez ensuite Meety.

Vous pouvez vérifier votre version actuelle en cliquant sur l'icône dans la barre de menu et en sélectionnant "About Meety".

## Utilisation

### Premier lancement

Au premier démarrage, macOS demande quatre permissions nécessaires au fonctionnement de Meety :

Le microphone pour enregistrer votre voix. L'enregistrement d'écran pour capturer l'audio système via ScreenCaptureKit (seul l'audio est capturé, jamais la vidéo). L'accès au dossier Documents pour sauvegarder les fichiers audio. Et l'API d'accessibilité pour détecter automatiquement les réunions Teams.

Si vous refusez une permission par inadvertance, vous pouvez l'activer ultérieurement dans Réglages Système > Confidentialité et sécurité. Les quatre permissions sont nécessaires pour un fonctionnement optimal.

### Enregistrer une réunion

Cliquez sur l'icône microphone dans votre barre de menu et sélectionnez "Démarrer l'enregistrement". L'icône devient rouge et affiche un timer. Pour arrêter, cliquez à nouveau et choisissez "Arrêter l'enregistrement". Le fichier est automatiquement sauvegardé dans Documents.

Si la détection automatique Teams est activée, l'application démarre l'enregistrement dès que vous rejoignez une réunion. Pratique pour ne jamais oublier d'enregistrer les échanges importants.

## Questions fréquentes

**Comment vérifier que l'enregistrement est actif ?**
L'icône dans la barre de menu passe au rouge et affiche un timer en temps réel pendant l'enregistrement.

**Où sont sauvegardés les enregistrements ?**
Dans votre dossier `~/Documents` avec la convention de nommage `meeting_YYYY-MM-DD_HH-mm-ss.m4a`. Par exemple, un enregistrement du 5 février 2025 à 14h30 produira `meeting_2025-02-05_14-30-15.m4a`.

**Meety fonctionne-t-il avec Zoom et Google Meet ?**
Oui. L'application capture l'audio système complet, ce qui la rend compatible avec toutes les solutions de visioconférence : Teams, Zoom, Meet, Discord, Slack, etc.

**Les données sont-elles privées ?**
Absolument. Tout le traitement s'effectue localement sur votre Mac. Aucune donnée n'est transmise vers le cloud, aucune télémétrie n'est collectée. Les fichiers restent dans votre dossier Documents.

**Que se passe-t-il si je ferme le couvercle pendant un enregistrement ?**
Sur macOS 15 et versions ultérieures, Meety tente de récupérer automatiquement l'enregistrement au réveil de la machine. Sur les versions antérieures, l'enregistrement peut s'interrompre. Pour les réunions importantes, il est préférable de garder votre Mac actif.

## Développement

Pour compiler le projet localement :

```bash
git clone https://github.com/florianchevallier/meeting-recorder.git
cd meeting-recorder
swift build
./.build/debug/MeetingRecorder
```

Le code est organisé en modules : `Audio/` gère la capture et le mixage audio avec AVAudioEngine et ScreenCaptureKit, `StatusBar/` contrôle l'interface dans la barre de menu, `Calendar/` implémente la détection des réunions Teams, et `Permissions/` coordonne les demandes d'autorisation système.

Les contributions sont bienvenues. Consultez [CONTRIBUTING.md](CONTRIBUTING.md) pour les directives. Les pull requests doivent être testées et ne pas introduire de régressions.

## Licence

Meety est distribué sous licence MIT. Vous pouvez utiliser, modifier et distribuer le code librement, à condition de conserver la notice de licence. Détails complets dans le fichier [LICENSE](LICENSE).
