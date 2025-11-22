#!/bin/bash

# Script de build local pour MeetingRecorder en mode production
# Usage: ./scripts/build-local.sh [--release] [--install] [--dmg]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
BUILD_CONFIG="release"
INSTALL=false
CREATE_DMG=false
VERSION="1.0.0"
APP_NAME="MeetingRecorder"
APP_DISPLAY_NAME="Meety"
APP_PATH="dist/Meety.app"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
🚀 Script de Build Local - MeetingRecorder

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --release     Build en mode release (par défaut)
    --debug       Build en mode debug
    --install     Installer l'app dans /Applications après le build
    --dmg         Créer un DMG pour la distribution
    --help        Afficher cette aide

EXEMPLES:
    $0                          # Build release sans installation
    $0 --install                # Build release et installer
    $0 --release --dmg          # Build release et créer DMG
    $0 --release --install      # Build release et installer
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_CONFIG="release"
            shift
            ;;
        --debug)
            BUILD_CONFIG="debug"
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Option inconnue: $1"
            show_usage
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

log_info "Configuration: $BUILD_CONFIG"
log_info "Installation: $INSTALL"
log_info "DMG: $CREATE_DMG"
echo ""

# 1. Nettoyer les builds précédents
log_info "Nettoyage des builds précédents..."
rm -rf dist
mkdir -p dist

# 2. Build Swift
log_info "Compilation Swift en mode $BUILD_CONFIG..."
ARCH=$(uname -m)
swift build --configuration "$BUILD_CONFIG"

# 3. Créer la structure du bundle
log_info "Création de la structure du bundle .app..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 4. Copier l'exécutable
log_info "Copie de l'exécutable..."
EXECUTABLE_PATH=".build/apple/Products/$BUILD_CONFIG/$APP_NAME"
if [ ! -f "$EXECUTABLE_PATH" ]; then
    # Fallback pour architecture spécifique
    EXECUTABLE_PATH=".build/$ARCH-apple-macosx/$BUILD_CONFIG/$APP_NAME"
fi

if [ ! -f "$EXECUTABLE_PATH" ]; then
    log_error "Exécutable non trouvé. Fichiers disponibles:"
    find .build -name "$APP_NAME" -type f 2>/dev/null || true
    exit 1
fi

cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/"

# 5. Copier Info.plist
log_info "Copie de Info.plist..."
cp Info.plist "$APP_PATH/Contents/"

# Mettre à jour la version dans Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true

# 6. Copier le bundle de localisation
log_info "Copie du bundle de localisation..."
LOCALIZATION_BUNDLE=".build/apple/Products/$BUILD_CONFIG/${APP_NAME}_${APP_NAME}.bundle"
if [ ! -d "$LOCALIZATION_BUNDLE" ]; then
    LOCALIZATION_BUNDLE=".build/$ARCH-apple-macosx/$BUILD_CONFIG/${APP_NAME}_${APP_NAME}.bundle"
fi

if [ -d "$LOCALIZATION_BUNDLE" ]; then
    cp -r "$LOCALIZATION_BUNDLE" "$APP_PATH/Contents/Resources/"
    
    # Copier l'icône directement dans Resources
    if [ -f "$LOCALIZATION_BUNDLE/AppIcon.icns" ]; then
        cp "$LOCALIZATION_BUNDLE/AppIcon.icns" "$APP_PATH/Contents/Resources/"
        log_success "Icône copiée dans Resources/"
    elif [ -f "Sources/Resources/Images/AppIcon.icns" ]; then
        cp "Sources/Resources/Images/AppIcon.icns" "$APP_PATH/Contents/Resources/"
        log_success "Icône copiée depuis Sources/Resources/Images/"
    else
        log_warning "AppIcon.icns non trouvé"
    fi
else
    log_warning "Bundle de localisation non trouvé à $LOCALIZATION_BUNDLE"
    log_info "Fichiers disponibles dans .build:"
    find .build -name "*.bundle" -type d 2>/dev/null | head -5 || true
fi

# 7. Copier les autres ressources
if [ -d "Sources/Resources" ]; then
    log_info "Copie des ressources supplémentaires..."
    cp -r Sources/Resources/* "$APP_PATH/Contents/Resources/" 2>/dev/null || true
fi

# 8. Créer PkgInfo
echo -n "APPL????" > "$APP_PATH/Contents/PkgInfo"

# 9. Rendre l'exécutable exécutable
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

# 10. Signer l'app avec entitlements
log_info "Signature de l'app avec entitlements..."
if [ -f "MeetingRecorder.entitlements" ]; then
    # ⚠️ IMPORTANT: Signature ad-hoc (-) = signature différente à chaque build
    # Cela signifie que les permissions TCC seront perdues après chaque mise à jour
    # Pour une signature stable, utiliser un certificat de développeur:
    # codesign --force --deep --sign "Developer ID Application: Your Name" --entitlements MeetingRecorder.entitlements "$APP_PATH"
    codesign --force --deep --sign - --entitlements MeetingRecorder.entitlements "$APP_PATH"
    log_success "App signée avec entitlements (ad-hoc)"
    log_warning "⚠️  Note: Signature ad-hoc = permissions TCC perdues après chaque mise à jour"
    log_info "💡 Pour préserver les permissions, utilisez le script d'installation: ./scripts/install-meety.sh"
    
    # Vérifier la signature
    log_info "Vérification de la signature..."
    codesign -dv "$APP_PATH" 2>&1 | head -3 || log_warning "Vérification signature échouée"
else
    log_warning "Fichier entitlements non trouvé, signature sans entitlements"
    codesign --force --deep --sign - "$APP_PATH"
fi

log_success "Bundle créé: $APP_PATH"

# 11. Créer le DMG si demandé
if [ "$CREATE_DMG" = true ]; then
    log_info "Création du DMG..."
    DMG_NAME="MeetingRecorder-${VERSION}.dmg"
    DMG_PATH="dist/$DMG_NAME"
    
    # Créer un dossier temporaire
    DMG_TEMP="dmg-temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"
    
    # Copier l'app
    cp -r "$APP_PATH" "$DMG_TEMP/"
    
    # Ajouter les instructions d'installation
    cat > "$DMG_TEMP/INSTALLATION.txt" << 'EOF'
📦 Meety Installation

🔧 Étapes d'installation:
1. Copier Meety.app vers /Applications
2. Clic droit sur l'app → "Ouvrir"
3. Cliquer "Ouvrir" dans la boîte de dialogue de sécurité
4. Accorder les permissions demandées

📋 Permissions requises:
- Accès au microphone
- Permission d'enregistrement d'écran
- Accès au calendrier (optionnel)

🚀 Pour commencer:
Cherchez l'icône microphone dans votre barre de menu après le lancement!
EOF
    
    # Créer un lien symbolique vers Applications
    ln -s /Applications "$DMG_TEMP/Applications"
    
    # Créer le DMG
    hdiutil create -volname "Meety" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$DMG_PATH"
    
    rm -rf "$DMG_TEMP"
    log_success "DMG créé: $DMG_PATH"
fi

# 12. Installer si demandé
if [ "$INSTALL" = true ]; then
    log_info "Installation dans /Applications..."
    
    # Arrêter l'app si elle tourne
    pkill -f "$APP_NAME" 2>/dev/null || true
    pkill -f "$APP_DISPLAY_NAME" 2>/dev/null || true
    
    # Supprimer l'ancienne installation
    rm -rf "/Applications/$APP_DISPLAY_NAME.app"
    
    # Copier la nouvelle
    cp -r "$APP_PATH" "/Applications/$APP_DISPLAY_NAME.app"
    
    log_success "App installée: /Applications/$APP_DISPLAY_NAME.app"
    log_info "Pour lancer: open /Applications/$APP_DISPLAY_NAME.app"
fi

echo ""
log_success "✅ Build terminé avec succès!"
echo ""
echo "📦 Fichiers créés:"
echo "   - Bundle: $APP_PATH"
if [ "$CREATE_DMG" = true ]; then
    echo "   - DMG: dist/$DMG_NAME"
fi
if [ "$INSTALL" = true ]; then
    echo "   - Installé: /Applications/$APP_DISPLAY_NAME.app"
fi
echo ""
echo "⚠️  IMPORTANT - Permissions TCC:"
echo "   La signature ad-hoc change à chaque build, donc les permissions seront perdues."
echo "   Utilisez le script d'installation pour gérer cela proprement:"
echo "   ./scripts/install-meety.sh [--dmg dist/MeetingRecorder-1.0.0.dmg]"
echo ""
echo "💡 Pour installer manuellement: faites un clic droit sur l'app → Ouvrir"

