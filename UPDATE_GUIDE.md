# 🔄 Guide de Mise à Jour - Meety

## ⚠️ Problème des Permissions TCC

**Important** : Chaque fois que vous rebuild l'application, elle obtient une **nouvelle signature ad-hoc**. macOS associe les permissions TCC au **bundle ID + signature**, donc les permissions sont perdues après chaque mise à jour.

### Pourquoi ça arrive ?

1. **Signature ad-hoc** (`codesign --sign -`) = signature unique à chaque build
2. **macOS identifie l'app** par bundle ID + signature
3. **Nouvelle signature** = nouvelle app aux yeux de macOS = permissions perdues

### Solutions

#### Option 1 : Script d'installation automatique (Recommandé)

```bash
# Installer depuis le DMG
./scripts/install-meety.sh --dmg dist/MeetingRecorder-1.0.0.dmg

# Installer depuis dist/
./scripts/install-meety.sh
```

Le script :
- ✅ Sauvegarde les permissions actuelles
- ✅ Installe la nouvelle version
- ✅ Réinitialise les permissions proprement
- ✅ Donne des instructions claires

#### Option 2 : Signature avec certificat développeur (Production)

Pour une signature stable qui préserve les permissions :

1. Obtenir un certificat "Developer ID Application" depuis Apple Developer
2. Modifier `scripts/build-local.sh` ligne 181 :
   ```bash
   codesign --force --deep --sign "Developer ID Application: Votre Nom" --entitlements MeetingRecorder.entitlements "$APP_PATH"
   ```

⚠️ **Note** : Cela nécessite un compte développeur Apple payant ($99/an).

#### Option 3 : Réaccorder manuellement (Simple)

Après chaque mise à jour :

1. Ouvrir l'app (clic droit → Ouvrir)
2. Accorder les permissions quand demandées
3. Ou ouvrir Réglages Système > Confidentialité et sécurité
4. Cocher Meety pour chaque permission

### Migration automatique des permissions

Malheureusement, macOS ne permet pas de migrer automatiquement les permissions TCC d'une signature à une autre pour des raisons de sécurité. C'est pourquoi vous devez réaccorder les permissions après chaque mise à jour avec une signature ad-hoc.

### Workflow recommandé pour développement

```bash
# 1. Build
./scripts/build-local.sh --release --dmg

# 2. Installer avec le script (gère les permissions)
./scripts/install-meety.sh --dmg dist/MeetingRecorder-1.0.0.dmg

# 3. Réaccorder les permissions quand demandées
```

### Vérifier les permissions actuelles

```bash
# Vérifier les permissions pour le bundle ID
tccutil check Microphone com.meetingrecorder.meety
tccutil check ScreenCapture com.meetingrecorder.meety
tccutil check Accessibility com.meetingrecorder.meety
```

### Réinitialiser complètement

Si les permissions sont corrompues :

```bash
./fix_permissions.sh
```

Puis réinstaller et réaccorder les permissions.


