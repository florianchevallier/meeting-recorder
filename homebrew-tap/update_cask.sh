#!/bin/bash

# Script to update the Homebrew cask with the latest release
# Usage: ./update_cask.sh [version] (e.g., ./update_cask.sh v0.1.10)

set -e

REPO="florianchevallier/meeting-recorder"
CASK_FILE="Casks/meety.rb"

# Get the latest version from GitHub if not provided
if [ -z "$1" ]; then
    VERSION=$(gh release list --repo "$REPO" --limit 1 --json tagName --jq '.[0].tagName')
    echo "Using latest version: $VERSION"
else
    VERSION="$1"
    echo "Using specified version: $VERSION"
fi

# Remove 'v' prefix for version number
VERSION_NUMBER="${VERSION#v}"

# Download URL
DMG_URL="https://github.com/$REPO/releases/download/$VERSION/MeetingRecorder-$VERSION_NUMBER.dmg"

echo "Downloading $DMG_URL to calculate SHA256..."

# Calculate SHA256
SHA256=$(curl -sL "$DMG_URL" | shasum -a 256 | cut -d' ' -f1)

echo "SHA256: $SHA256"

# Update the cask
echo "Updating cask..."

# Use sed to update the cask
sed -i '' "s|version \".*\"|version \"$VERSION_NUMBER\"|" "$CASK_FILE"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$CASK_FILE"

echo "✅ Cask updated successfully!"
echo ""
echo "Changes made to $CASK_FILE:"
echo "- Version: $VERSION_NUMBER"
echo "- SHA256: $SHA256"
echo ""
echo "Next steps:"
echo "1. Test the cask: brew install --cask $CASK_FILE"
echo "2. Commit and push changes to the tap repository"
echo "3. Test installation: brew uninstall --cask meety && brew install --cask meety"