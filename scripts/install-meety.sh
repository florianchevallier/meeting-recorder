#!/bin/bash

# Script d'installation pour Meety avec gestion des permissions TCC
# Usage: ./scripts/install-meety.sh [--dmg path/to/dmg]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.meetingrecorder.meety"
APP_NAME="Meety.app"
APP_PATH="/Applications/$APP_NAME"

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

# 1. Arrêter l'app si elle tourne
log_info "Arrêt de l'application si elle est en cours d'exécution..."
pkill -f MeetingRecorder 2>/dev/null || true
pkill -f Meety 2>/dev/null || true
sleep 1

# 2. Sauvegarder les permissions actuelles (si l'app existe)
if [ -d "$APP_PATH" ]; then
    log_info "Sauvegarde des permissions actuelles..."
    
    # Vérifier quelles permissions étaient accordées
    MIC_PERMISSION=$(tccutil check Microphone "$BUNDLE_ID" 2>/dev/null || echo "unknown")
    SCREEN_PERMISSION=$(tccutil check ScreenCapture "$BUNDLE_ID" 2>/dev/null || echo "unknown")
    ACCESS_PERMISSION=$(tccutil check Accessibility "$BUNDLE_ID" 2>/dev/null || echo "unknown")
    
    log_info "Permissions actuelles:"
    log_info "  - Microphone: $MIC_PERMISSION"
    log_info "  - Screen Capture: $SCREEN_PERMISSION"
    log_info "  - Accessibility: $ACCESS_PERMISSION"
else
    log_info "Application non trouvée, première installation"
    MIC_PERMISSION="unknown"
    SCREEN_PERMISSION="unknown"
    ACCESS_PERMISSION="unknown"
fi

# 3. Supprimer l'ancienne app
log_info "Suppression de l'ancienne version..."
rm -rf "$APP_PATH"

# 4. Copier la nouvelle app
if [ -n "${1:-}" ] && [ "$1" = "--dmg" ] && [ -n "${2:-}" ]; then
    DMG_PATH="$2"
    log_info "Installation depuis DMG: $DMG_PATH"
    
    # Monter le DMG
    VOLUME=$(hdiutil attach "$DMG_PATH" | grep -o '/Volumes/[^[:space:]]*' | head -1)
    APP_SOURCE="$VOLUME/$APP_NAME"
    
    # Copier l'app
    cp -R "$APP_SOURCE" "$APP_PATH"
    
    # Démontrer le DMG
    hdiutil detach "$VOLUME" >/dev/null 2>&1 || true
elif [ -d "$PROJECT_DIR/dist/$APP_NAME" ]; then
    log_info "Installation depuis dist/"
    cp -R "$PROJECT_DIR/dist/$APP_NAME" "$APP_PATH"
else
    log_error "Aucune application trouvée à installer"
    log_info "Utilisation: $0 [--dmg path/to/Meety.dmg]"
    log_info "Ou assurez-vous que dist/$APP_NAME existe"
    exit 1
fi

log_success "Application installée: $APP_PATH"

# 5. Réinitialiser les permissions pour forcer la nouvelle demande
log_info "Réinitialisation des permissions TCC pour la nouvelle signature..."
sudo tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || log_warning "Impossible de réinitialiser Microphone"
sudo tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null || log_warning "Impossible de réinitialiser ScreenCapture"
sudo tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || log_warning "Impossible de réinitialiser Accessibility"

# 6. Supprimer les préférences pour un démarrage propre
log_info "Nettoyage des préférences..."
defaults delete "$BUNDLE_ID" 2>/dev/null || true

# 7. Instructions pour l'utilisateur
echo ""
log_success "✅ Installation terminée !"
echo ""
log_warning "⚠️  IMPORTANT : Les permissions doivent être réaccordées"
echo ""
echo "📋 Étapes suivantes :"
echo ""
echo "1. Ouvrir l'application :"
echo "   open \"$APP_PATH\""
echo ""
echo "2. Accorder les permissions quand elles sont demandées :"
echo "   - Microphone ✅"
echo "   - Enregistrement d'écran ✅"
echo "   - Accessibilité ✅"
echo ""
echo "3. Si les permissions ne sont pas demandées automatiquement :"
echo "   - Ouvrir Réglages Système > Confidentialité et sécurité"
echo "   - Cocher Meety pour chaque permission"
echo ""
echo "💡 Astuce : Vous pouvez aussi utiliser :"
echo "   ./fix_permissions.sh"
echo "   pour réinitialiser complètement toutes les permissions"
echo ""
echo "📚 Pourquoi les permissions sont perdues ?"
echo "   La signature ad-hoc change à chaque build (gratuit mais temporaire)."
echo "   Pour une signature stable, il faut un compte développeur Apple ($99/an)."
echo "   Voir CODE_SIGNING_GUIDE.md pour plus d'informations."

