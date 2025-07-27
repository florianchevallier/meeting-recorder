#!/bin/bash

# Script pour mettre à jour l'icône de l'application
# Usage: ./update-icon.sh [chemin_vers_nouvelle_icone.png]
# Si aucun chemin n'est fourni, met à jour avec l'icône actuelle

set -euo pipefail

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$PROJECT_DIR/Sources/Resources/Images"
CURRENT_ICON="$ICON_DIR/AppIcon.png"
ICONSET_DIR="$ICON_DIR/AppIcon.iconset"
ICNS_FILE="$ICON_DIR/AppIcon.icns"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

validate_icon() {
    local icon_file="$1"
    
    if [ ! -f "$icon_file" ]; then
        log_error "Fichier d'icône introuvable: $icon_file"
        exit 1
    fi
    
    # Vérifier que c'est un PNG
    if ! file "$icon_file" | grep -q "PNG image data"; then
        log_error "Le fichier doit être un PNG valide"
        exit 1
    fi
    
    # Obtenir les dimensions
    local dimensions=$(sips -g pixelWidth -g pixelHeight "$icon_file" 2>/dev/null | tail -2 | awk '{print $2}')
    local width=$(echo "$dimensions" | head -1)
    local height=$(echo "$dimensions" | tail -1)
    
    log_info "Dimensions de l'icône: ${width}x${height}"
    
    # Recommandation pour les dimensions
    if [ "$width" -lt 512 ] || [ "$height" -lt 512 ]; then
        log_warning "Recommandation: utilisez une icône d'au moins 512x512 pour une meilleure qualité"
    fi
    
    if [ "$width" != "$height" ]; then
        log_warning "L'icône n'est pas carrée (${width}x${height}), elle sera redimensionnée"
    fi
}

generate_iconset() {
    local source_icon="$1"
    
    log_info "Génération de l'iconset à partir de: $(basename "$source_icon")"
    
    # Supprimer l'ancien iconset s'il existe
    if [ -d "$ICONSET_DIR" ]; then
        rm -rf "$ICONSET_DIR"
    fi
    
    # Créer le dossier iconset
    mkdir -p "$ICONSET_DIR"
    
    # Générer toutes les tailles nécessaires
    local sizes=(
        "16:icon_16x16.png"
        "32:icon_16x16@2x.png"
        "32:icon_32x32.png"
        "64:icon_32x32@2x.png"
        "128:icon_128x128.png"
        "256:icon_128x128@2x.png"
        "256:icon_256x256.png"
        "512:icon_256x256@2x.png"
        "512:icon_512x512.png"
        "1024:icon_512x512@2x.png"
    )
    
    for size_info in "${sizes[@]}"; do
        local size="${size_info%:*}"
        local filename="${size_info#*:}"
        
        log_info "Génération ${size}x${size} -> $filename"
        sips -z "$size" "$size" "$source_icon" --out "$ICONSET_DIR/$filename" >/dev/null
        
        if [ ! -f "$ICONSET_DIR/$filename" ]; then
            log_error "Échec de la génération de $filename"
            exit 1
        fi
    done
    
    log_success "Iconset généré avec succès: $(ls "$ICONSET_DIR" | wc -l | xargs) fichiers"
}

generate_icns() {
    log_info "Génération du fichier .icns"
    
    # Supprimer l'ancien fichier .icns s'il existe
    if [ -f "$ICNS_FILE" ]; then
        rm -f "$ICNS_FILE"
    fi
    
    # Créer le fichier .icns
    iconutil -c icns "$ICONSET_DIR" --output "$ICNS_FILE"
    
    if [ ! -f "$ICNS_FILE" ]; then
        log_error "Échec de la génération du fichier .icns"
        exit 1
    fi
    
    # Vérifier la taille du fichier généré
    local file_size=$(ls -lh "$ICNS_FILE" | awk '{print $5}')
    log_success "Fichier .icns généré: $file_size"
}

show_rebuild_instructions() {
    log_info "Icône mise à jour avec succès!"
    echo ""
    echo "🔨 Pour appliquer la nouvelle icône, rebuilder l'application:"
    echo "   ./debug_app.sh              # Pour debug"
    echo "   ./scripts/build-dev.sh      # Pour development"
    echo "   git commit + tag + push     # Pour GitHub Actions"
    echo ""
    echo "📁 Fichiers mis à jour:"
    echo "   ✅ $ICNS_FILE"
    echo "   ✅ $ICONSET_DIR/ ($(ls "$ICONSET_DIR" | wc -l | xargs) fichiers)"
    if [ -n "${NEW_ICON:-}" ]; then
        echo "   ✅ $CURRENT_ICON (remplacé)"
    fi
}

main() {
    local new_icon="${1:-}"
    
    log_info "🎨 Mise à jour de l'icône de l'application"
    
    # Si un fichier est fourni, remplacer l'icône actuelle
    if [ -n "$new_icon" ]; then
        log_info "Nouvelle icône fournie: $new_icon"
        validate_icon "$new_icon"
        
        # Copier la nouvelle icône
        cp "$new_icon" "$CURRENT_ICON"
        log_success "Icône remplacée: $(basename "$new_icon") -> AppIcon.png"
        NEW_ICON="$new_icon"
    else
        log_info "Utilisation de l'icône actuelle: AppIcon.png"
        validate_icon "$CURRENT_ICON"
    fi
    
    # Générer l'iconset et le fichier .icns
    generate_iconset "$CURRENT_ICON"
    generate_icns
    
    # Nettoyer l'iconset temporaire (optionnel)
    # rm -rf "$ICONSET_DIR"
    
    show_rebuild_instructions
}

# Afficher l'aide si demandé
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [chemin_vers_nouvelle_icone.png]"
    echo ""
    echo "Met à jour l'icône de l'application MeetingRecorder."
    echo ""
    echo "Arguments:"
    echo "  chemin_vers_nouvelle_icone.png  Chemin vers la nouvelle icône (optionnel)"
    echo "                                   Si omis, régénère avec l'icône actuelle"
    echo ""
    echo "Exemples:"
    echo "  $0                              # Régénère avec l'icône actuelle"
    echo "  $0 ~/Desktop/new-icon.png       # Utilise une nouvelle icône"
    echo "  $0 --help                       # Affiche cette aide"
    echo ""
    echo "L'icône doit être un fichier PNG. Recommandé: 512x512 ou plus, format carré."
    exit 0
fi

# Exécuter la fonction principale
main "$@"