# 📦 Guide d'Installation - MeetingRecorder

Application native macOS pour enregistrer automatiquement vos réunions Microsoft Teams.

---

## 🔧 Installation Standard (Recommandée)

### Étape 1 : Télécharger
1. Aller sur [Releases](https://github.com/florianchevallier/meeting-recorder/releases)
2. Télécharger le fichier `.dmg` le plus récent
3. Monter le DMG (double-clic)

### Étape 2 : Installer
1. **Glisser** `MeetingRecorder.app` vers le dossier `Applications`
2. **Aller** dans Applications
3. **Clic droit** sur `MeetingRecorder.app` → **"Ouvrir"**
4. **Cliquer "Ouvrir"** dans la boîte de dialogue de sécurité

### Étape 3 : Permissions
L'app demandera les permissions suivantes :
- ✅ **Microphone** : Pour enregistrer votre voix
- ✅ **Enregistrement d'écran** : Pour capturer l'audio système  
- ✅ **Calendrier** : Pour détecter automatiquement les réunions (optionnel)

**Accorder TOUTES les permissions** pour un fonctionnement optimal.

---

## 🛡️ Installation Alternative (Utilisateurs Avancés)

Si l'installation standard ne fonctionne pas :

### Méthode 1 : Désactiver Gatekeeper Temporairement
```bash
# Désactiver Gatekeeper
sudo spctl --master-disable

# Installer et lancer l'app normalement
open /Applications/MeetingRecorder.app

# Réactiver Gatekeeper (recommandé)
sudo spctl --master-enable
```

### Méthode 2 : Autoriser Spécifiquement l'App
```bash
# Autoriser l'app spécifiquement
sudo spctl --add /Applications/MeetingRecorder.app
sudo spctl --enable /Applications/MeetingRecorder.app
```

### Méthode 3 : Retirer la Quarantaine
```bash
# Retirer l'attribut de quarantaine
sudo xattr -rd com.apple.quarantine /Applications/MeetingRecorder.app
```

---

## 🚀 Première Utilisation

### 1. Lancement
- Chercher l'icône **microphone** dans la barre de menu (en haut à droite)
- Si invisible : relancer l'app depuis Applications

### 2. Configuration Initiale
1. **Permissions** : Accorder microphone + enregistrement d'écran
2. **Test** : Cliquer sur l'icône → "Démarrer l'enregistrement"
3. **Vérifier** : Parler dans le micro + jouer du son
4. **Arrêter** : Cliquer → "Arrêter l'enregistrement"
5. **Fichier** : Vérifier dans `~/Documents/meeting_*.m4a`

### 3. Fonctionnalités
- **Enregistrement Manuel** : Via menu status bar
- **Auto-détection Teams** : L'app détecte automatiquement les réunions
- **Qualité Audio** : 48kHz stéréo, format M4A
- **Nommage Intelligent** : `meeting_YYYY-MM-DD_HH-mm-ss.m4a`

---

## 🔧 Résolution de Problèmes

### L'app ne se lance pas
```bash
# Vérifier les permissions
ls -la /Applications/MeetingRecorder.app
xattr -l /Applications/MeetingRecorder.app

# Forcer l'ouverture
open /Applications/MeetingRecorder.app
```

### Permissions refusées
1. **Système** → **Confidentialité et sécurité**
2. **Microphone** → Ajouter MeetingRecorder
3. **Enregistrement d'écran** → Ajouter MeetingRecorder
4. **Redémarrer l'app**

### Pas d'icône dans la barre de menu
1. Vérifier si l'app tourne : `ps aux | grep MeetingRecorder`
2. Relancer depuis Applications
3. Vérifier les logs Console.app

### Enregistrement silencieux
1. **Tester le micro** : Préférences Système → Son → Entrée
2. **Tester l'audio système** : Jouer de la musique
3. **Vérifier les permissions** d'enregistrement d'écran
4. **Redémarrer l'app** après changement de permissions

### Fichiers non créés
1. Vérifier le dossier : `ls ~/Documents/meeting_*.m4a`
2. Permissions dossier Documents
3. Espace disque disponible
4. Logs dans Console.app

---

## 📋 Configuration Système Requise

### Minimum
- **macOS 13.0** (Ventura) ou supérieur
- **8 GB RAM** recommandés
- **100 MB** espace disque libre
- **Microphone** intégré ou externe

### Optimale  
- **macOS 14.0+** pour toutes les fonctionnalités
- **16 GB RAM** pour enregistrements longs
- **SSD** pour performances optimales
- **Microphone externe** pour meilleure qualité

### Compatibilité
- ✅ **Apple Silicon** (M1, M2, M3)
- ✅ **Intel** (x86_64)
- ✅ **Teams** (version desktop)
- ⚠️ **Teams Web** (détection limitée)

---

## 🔒 Sécurité et Confidentialité

### Pourquoi l'app est sûre
- ✅ **Code source ouvert** sur GitHub
- ✅ **Build automatisé** via GitHub Actions
- ✅ **Pas de télémétrie** ou tracking
- ✅ **Données locales** uniquement
- ✅ **Pas de connexion réseau** requise

### Données collectées
- **AUCUNE** donnée envoyée en ligne
- **Enregistrements** stockés localement uniquement
- **Permissions** demandées explicitement
- **Pas d'analytics** ou crash reporting

### Recommandations
- ✅ Installer depuis les releases GitHub officielles
- ✅ Vérifier le hash SHA256 si nécessaire
- ✅ Garder macOS à jour
- ⚠️ Ne pas installer depuis sources tierces

---

## 📞 Support et Aide

### Documentation
- 📖 [README.md](README.md) - Vue d'ensemble
- 🔧 [CLAUDE.md](CLAUDE.md) - Documentation technique
- 🚀 [DEPLOYMENT.md](DEPLOYMENT.md) - Guide de déploiement

### Support Communautaire
- 🐛 **Bugs** : [Ouvrir une issue](https://github.com/florianchevallier/meeting-recorder/issues)
- 💡 **Suggestions** : [Discussions GitHub](https://github.com/florianchevallier/meeting-recorder/discussions)
- ❓ **Questions** : [Issues Q&A](https://github.com/florianchevallier/meeting-recorder/issues)

### Logs de Debug
Pour rapporter un bug, inclure :
```bash
# Logs système
log show --predicate 'subsystem contains "MeetingRecorder"' --last 1h

# Permissions actuelles
tccutil dump | grep MeetingRecorder

# Informations système
sw_vers && system_profiler SPAudioDataType
```

---

## 🎉 Merci !

MeetingRecorder est développé par passion pour améliorer l'expérience des réunions à distance.

**Star le repo** ⭐ si l'app vous aide !
**Contribuer** 🤝 si vous voulez améliorer le code !
**Partager** 📢 avec vos collègues qui en ont besoin !