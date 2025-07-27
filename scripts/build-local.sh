#!/bin/bash

# MeetingRecorder Local Build Script (No Apple Developer Account)
# Usage: ./scripts/build-local.sh [--release] [--install]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
BUILD_TYPE="debug"
INSTALL_APP=false
VERSION="0.1.0-local"

# Functions
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
Usage: $0 [OPTIONS]

OPTIONS:
    --release      Build in release mode (optimized)
    --install      Install app to /Applications after build
    --help         Show this help message

EXAMPLES:
    $0                    # Debug build only
    $0 --release         # Release build
    $0 --release --install # Build and install

OUTPUT:
    - App bundle: dist/MeetingRecorder.app
    - DMG (release): dist/MeetingRecorder-local.dmg

SECURITY NOTE:
    This creates an UNSIGNED build that will trigger macOS security warnings.
    Users need to right-click → Open to run the app.
EOF
}

check_requirements() {
    log_info "Checking build requirements..."
    
    # Check macOS version
    if [[ $(sw_vers -productVersion | cut -d. -f1) -lt 13 ]]; then
        log_warning "macOS 13+ recommended for ScreenCaptureKit features"
    fi
    
    # Check Xcode/Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift is required but not found."
        log_info "Install Xcode or Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    # Check Swift version
    SWIFT_VERSION=$(swift --version | head -n1)
    log_info "Using: $SWIFT_VERSION"
    
    # Check if in project root
    if [[ ! -f "$PROJECT_ROOT/Package.swift" ]]; then
        log_error "Not in MeetingRecorder project root"
        exit 1
    fi
    
    log_success "All requirements met"
}

clean_build() {
    log_info "Cleaning previous builds..."
    
    cd "$PROJECT_ROOT"
    
    # Clean Swift build cache
    rm -rf .build
    
    # Clean dist folder
    rm -rf dist
    mkdir -p dist
    
    log_success "Build environment cleaned"
}

build_app() {
    log_info "Building MeetingRecorder ($BUILD_TYPE mode)..."
    
    cd "$PROJECT_ROOT"
    
    # Build based on type
    if [[ "$BUILD_TYPE" == "release" ]]; then
        swift build --configuration release --arch arm64 --arch x86_64
        BUILD_PATH=".build/apple/Products/Release"
    else
        swift build --configuration debug
        BUILD_PATH=".build/debug"
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Build failed"
        exit 1
    fi
    
    log_success "Build completed successfully"
    
    # Create app bundle
    create_app_bundle "$BUILD_PATH"
}

create_app_bundle() {
    local build_path=$1
    
    log_info "Creating app bundle..."
    
    APP_NAME="MeetingRecorder"
    APP_PATH="dist/${APP_NAME}.app"
    
    # Create bundle structure
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    
    # Copy executable
    cp "$build_path/${APP_NAME}" "$APP_PATH/Contents/MacOS/"
    
    # Make executable
    chmod +x "$APP_PATH/Contents/MacOS/${APP_NAME}"
    
    # Copy Info.plist with version
    cp Info.plist "$APP_PATH/Contents/"
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M)" "$APP_PATH/Contents/Info.plist"
    
    # Copy resources if they exist
    if [[ -d "Sources/Resources" ]]; then
        cp -r Sources/Resources/* "$APP_PATH/Contents/Resources/"
    fi
    
    # Create placeholder icon if missing
    if [[ ! -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
        log_warning "No app icon found - app will use default system icon"
    fi
    
    # Add security warning file
    cat > "$APP_PATH/Contents/Resources/SECURITY_WARNING.txt" << 'EOF'
⚠️  UNSIGNED APPLICATION WARNING

This application is NOT signed with an Apple Developer certificate.
macOS will show security warnings when you try to run it.

TO RUN THIS APP:
1. Right-click on the app → "Open"
2. Click "Open" in the security dialog
3. Grant permissions when requested

ALTERNATIVE (Disable Gatekeeper temporarily):
sudo spctl --master-disable
# Run the app
sudo spctl --master-enable

This is safe because:
- Source code is available and auditable
- Built locally on your machine
- No malicious code added

For a signed version, the developer needs an Apple Developer account ($99/year).
EOF
    
    log_success "App bundle created: $APP_PATH"
    
    # Show bundle info
    echo "📦 Bundle contents:"
    ls -la "$APP_PATH/Contents/MacOS/"
    echo "📝 Info.plist version:"
    plutil -p "$APP_PATH/Contents/Info.plist" | grep -E "(CFBundleShortVersionString|CFBundleVersion)"
}

create_dmg() {
    if [[ "$BUILD_TYPE" != "release" ]]; then
        log_info "Skipping DMG creation (debug build)"
        return 0
    fi
    
    log_info "Creating DMG installer..."
    
    DMG_NAME="MeetingRecorder-${VERSION}.dmg"
    DMG_PATH="dist/$DMG_NAME"
    
    # Create temporary folder
    mkdir -p dmg-temp
    cp -r "dist/MeetingRecorder.app" dmg-temp/
    
    # Add installation instructions
    cat > dmg-temp/INSTALLATION_GUIDE.txt << 'EOF'
📦 MeetingRecorder Installation Guide

⚠️  SECURITY WARNING:
This app is NOT signed with an Apple Developer certificate.
macOS will show security warnings.

🔧 INSTALLATION STEPS:
1. Drag MeetingRecorder.app to Applications folder
2. Go to Applications folder
3. Right-click on MeetingRecorder.app → "Open"
4. Click "Open" in the security dialog
5. Grant microphone/screen recording permissions when asked

🛡️  ALTERNATIVE METHOD (Advanced users):
Open Terminal and run:
sudo spctl --master-disable
# Now you can run the app normally
sudo spctl --master-enable

📋 REQUIRED PERMISSIONS:
- Microphone access (for recording your voice)
- Screen recording (for capturing system audio)
- Calendar access (optional, for auto-detection)

ℹ️  WHY UNSIGNED?
The developer doesn't have an Apple Developer account ($99/year).
The app is still safe - source code is publicly available.

🚀 GETTING STARTED:
1. Look for the microphone icon in your menu bar
2. Click it to start/stop recording
3. Recordings saved to ~/Documents/

For support: https://github.com/your-repo/issues
EOF
    
    # Create symlink to Applications
    ln -s /Applications dmg-temp/Applications
    
    # Create DMG
    hdiutil create -volname "MeetingRecorder (Unsigned)" \
        -srcfolder dmg-temp \
        -ov -format UDZO \
        "$DMG_PATH"
    
    # Clean up temp folder
    rm -rf dmg-temp
    
    log_success "DMG created: $DMG_PATH"
}

install_app() {
    if [[ "$INSTALL_APP" == false ]]; then
        return 0
    fi
    
    log_info "Installing app to /Applications..."
    
    # Remove existing installation
    if [[ -d "/Applications/MeetingRecorder.app" ]]; then
        log_warning "Removing existing installation"
        rm -rf "/Applications/MeetingRecorder.app"
    fi
    
    # Copy new version
    cp -r "dist/MeetingRecorder.app" "/Applications/"
    
    log_success "App installed to /Applications/MeetingRecorder.app"
    log_warning "Remember: Right-click → Open to bypass security warnings"
}

show_next_steps() {
    echo
    log_success "🎉 Build completed successfully!"
    echo
    echo "📦 Files created:"
    ls -la dist/
    echo
    
    if [[ "$INSTALL_APP" == true ]]; then
        echo "✅ App installed to /Applications/"
        echo "🚀 Launch from Applications folder (right-click → Open)"
    else
        echo "🚀 To install: ./scripts/build-local.sh --release --install"
        echo "🔍 Or run directly: open dist/MeetingRecorder.app"
    fi
    
    echo
    log_warning "⚠️  INSTALLATION REMINDER:"
    echo "   Right-click the app → 'Open' to bypass security warnings"
    echo "   Grant microphone/screen recording permissions when asked"
    echo
    echo "💡 For automatic permission setup:"
    echo "   System Settings → Privacy & Security → Full Disk Access"
    echo "   Add Terminal.app to allow this script to help with permissions"
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --release)
                BUILD_TYPE="release"
                shift
                ;;
            --install)
                INSTALL_APP=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Main execution
    log_info "Starting local build process..."
    log_info "Build type: $BUILD_TYPE"
    log_info "Install after build: $INSTALL_APP"
    
    check_requirements
    clean_build
    build_app
    create_dmg
    install_app
    show_next_steps
}

# Execute main function with all arguments
main "$@"