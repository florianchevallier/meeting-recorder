# 🚀 Guide de Déploiement - MeetingRecorder

## Vue d'ensemble

Pipeline CI/CD automatisé pour MeetingRecorder avec distribution via GitHub Releases.

---

## 🚀 Utilisation Immédiate

### Build Local
```bash
# Build et installation locale
./scripts/build-local.sh --release --install

# Build sans installation
./scripts/build-local.sh --release
```

### Release Automatique
```bash
# Créer et pousser un tag pour déclencher la release
git tag v1.0.0
git push origin v1.0.0
```

**Pipeline** : `.github/workflows/ci.yml`
- ✅ Tests automatiques sur macOS 13+
- ✅ Build multi-architecture (arm64 + x86_64)  
- ✅ DMG avec instructions d'installation
- ✅ Release GitHub avec assets

---

## 🔄 Processus de Release

### Déclenchement Automatique

Le pipeline se déclenche sur :
- **Push sur tags** : `v*` (ex: v1.0.0) → Release complète
- **Push sur main** : Build de développement
- **Pull requests** : Tests uniquement

### Étapes du Pipeline

#### 1. **Test Job** 
```yaml
Environnement: macOS-13, Xcode 15.1
- Checkout du code
- Cache SPM pour performances
- Build debug
- Exécution tests unitaires
- Validation structure package
```

#### 2. **Build Job**
```yaml
Déclenchement: Push main ou tags v*
- Extraction version depuis tag
- Mise à jour Info.plist automatique  
- Build release (arm64 + x86_64)
- Création bundle .app structure
- Upload artifacts pour release
```

#### 3. **Release Job** (Tags uniquement)
```yaml
Déclenchement: Tags v* uniquement
- Téléchargement artifacts de build
- Génération release notes automatiques
- Création GitHub Release publique
- Publication DMG téléchargeable
- Notification succès avec liens
```

---

## 🛠️ Scripts Disponibles

### Script de Build Local

```bash
# Afficher l'aide
./scripts/build-local.sh --help

# Build debug rapide
./scripts/build-local.sh

# Build release optimisé
./scripts/build-local.sh --release

# Build + installation automatique
./scripts/build-local.sh --release --install
```

**Fonctionnalités** :
- ✅ Nettoyage automatique des builds précédents
- ✅ Validation des prérequis système
- ✅ Création bundle .app complet
- ✅ DMG pour release avec instructions
- ✅ Installation directe en Applications

### Release Manuelle Simple

```bash
# 1. Vérifier l'état du repo
git status
swift test

# 2. Créer et pousser le tag
git tag v1.0.0
git push origin v1.0.0

# 3. Surveiller le pipeline
gh run watch --repo florianchevallier/meeting-recorder
```

---

## 📋 Checklist de Release

### Pré-Release
- [ ] Tests passent localement (`swift test`)
- [ ] Code review approuvé et mergé
- [ ] CHANGELOG.md mis à jour avec nouveautés
- [ ] Version cohérente et incrémentée
- [ ] Pas de TODOs ou FIXMEs critiques

### Validation Pipeline
- [ ] Tests CI passent sur macOS 13+
- [ ] Build artifacts générés correctement
- [ ] DMG créé avec instructions
- [ ] Release notes générées automatiquement

### Post-Release
- [ ] GitHub Release créée et publique
- [ ] DMG téléchargeable depuis releases
- [ ] Installation testée sur machine propre
- [ ] Monitoring issues/feedback activé

---

## 🔧 Configuration Système

### Prérequis Développement
- **macOS 13.0+** pour ScreenCaptureKit complet
- **Xcode 15.1+** ou Command Line Tools
- **Swift 5.9+** avec Package Manager
- **GitHub CLI** pour releases manuelles (optionnel)

### Structure de Build
```
dist/
├── MeetingRecorder.app          # Bundle app complet
└── MeetingRecorder-v1.0.0.dmg   # Installateur DMG
```

### Configuration Audio
```swift
// Optimisée pour performance et qualité
config.capturesAudio = true
config.sampleRate = 48000
config.channelCount = 2
config.excludesCurrentProcessAudio = true
```

---

## 🚨 Dépannage

### Échec de Build Local
```bash
# Nettoyage complet
rm -rf .build dist
swift package clean

# Rebuild avec logs détaillés
swift build --configuration release --verbose
```

### Échec Pipeline CI
```bash
# Vérifier status des actions
gh run list --repo florianchevallier/meeting-recorder

# Voir logs d'une run spécifique
gh run view <run-id> --log
```

### Problèmes d'Installation
```bash
# Vérifier permissions app
ls -la /Applications/MeetingRecorder.app
xattr -l /Applications/MeetingRecorder.app

# Forcer ouverture si bloquée
open /Applications/MeetingRecorder.app
```

### Permissions macOS
1. **Préférences Système** → **Confidentialité et sécurité**
2. **Microphone** → Ajouter MeetingRecorder ✅
3. **Enregistrement d'écran** → Ajouter MeetingRecorder ✅
4. **Calendrier** → Ajouter MeetingRecorder ✅ (optionnel)

---

## 📊 Métriques Performance

### Temps de Pipeline
- **Tests** : ~3-5 minutes
- **Build** : ~5-10 minutes  
- **Release** : ~2-5 minutes
- **Total** : ~10-20 minutes

### Optimisations Actives
- ✅ Cache SPM pour dépendances
- ✅ Builds parallèles multi-architecture
- ✅ Artifacts compressés
- ✅ Notifications temps réel

### Taille des Assets
- **App Bundle** : ~5-10 MB
- **DMG** : ~8-15 MB
- **Download** : Rapide même sur connexions lentes

---

## 🔗 Liens Utiles

- 📦 **[Releases](https://github.com/florianchevallier/meeting-recorder/releases)** - Téléchargements
- 🐛 **[Issues](https://github.com/florianchevallier/meeting-recorder/issues)** - Support et bugs
- 🔧 **[Actions](https://github.com/florianchevallier/meeting-recorder/actions)** - Status pipeline
- 📖 **[Documentation Apple](https://developer.apple.com/documentation/screencapturekit)** - ScreenCaptureKit

---

## 📞 Support Pipeline

Pour les problèmes de déploiement :

1. 🔍 **Vérifier logs** GitHub Actions avec liens directs
2. 📚 **Consulter ce guide** de dépannage section par section  
3. 🐛 **Ouvrir issue** avec logs complets et contexte
4. 💬 **Discussion** pour questions générales ou améliorations

**Le pipeline est conçu pour être robuste et informatif !** 🎉