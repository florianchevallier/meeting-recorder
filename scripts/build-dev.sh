#!/bin/bash

# Build script for development version (MeetyDev)
# Creates a separate app with different bundle ID to avoid permission conflicts

set -euo pipefail

# Configuration
PROJECT_NAME="MeetingRecorder"
DEV_APP_NAME="MeetyDev"
BUNDLE_ID_DEV="com.meetingrecorder.dev"
VERSION="1.0.0-dev"

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

main() {
    log_info "Building development version: $DEV_APP_NAME"
    
    # Clean previous builds
    log_info "Cleaning previous builds..."
    swift package clean
    rm -rf dist/
    
    # Build the executable
    log_info "Building Swift package..."
    swift build --configuration release
    
    local BUILD_PATH=".build/apple/Products/Release"
    if [ ! -d "$BUILD_PATH" ]; then
        BUILD_PATH=".build/arm64-apple-macosx/release"
    fi
    
    if [ ! -f "$BUILD_PATH/$PROJECT_NAME" ]; then
        log_error "Build failed - executable not found at $BUILD_PATH/$PROJECT_NAME"
        exit 1
    fi
    
    # Create dev app bundle
    create_dev_app_bundle "$BUILD_PATH"
    
    log_success "Development build completed!"
    log_info "Location: dist/$DEV_APP_NAME.app"
    log_info "Bundle ID: $BUNDLE_ID_DEV"
    log_warning "This version has separate permissions from production Meety"
}

create_dev_app_bundle() {
    local build_path="$1"
    local app_path="dist/$DEV_APP_NAME.app"
    
    log_info "Creating development app bundle..."
    
    # Create bundle structure
    mkdir -p "$app_path/Contents/MacOS"
    mkdir -p "$app_path/Contents/Resources"
    
    # Copy executable
    cp "$build_path/$PROJECT_NAME" "$app_path/Contents/MacOS/"
    chmod +x "$app_path/Contents/MacOS/$PROJECT_NAME"
    
    # Use development Info.plist
    cp "Info-Dev.plist" "$app_path/Contents/Info.plist"
    
    # Update version in Info.plist
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$app_path/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M)" "$app_path/Contents/Info.plist"
    
    # Copy resource bundle if it exists
    if [ -d "$build_path/MeetingRecorder_MeetingRecorder.bundle" ]; then
        cp -R "$build_path/MeetingRecorder_MeetingRecorder.bundle" "$app_path/Contents/Resources/"
    fi
    
    log_success "Development app bundle created: $app_path"
    
    # Show bundle info
    plutil -p "$app_path/Contents/Info.plist" | grep -E "(CFBundle(Identifier|DisplayName|ShortVersionString|Version))"
}

# Run main function
main "$@"