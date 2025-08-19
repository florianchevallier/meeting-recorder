#!/bin/bash

# Update formula script for current structure (Casks/meety.rb)
# Usage: ./update_formula.sh v1.2.3

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version_tag>"
    echo "Example: $0 v1.2.3"
    exit 1
fi

VERSION_TAG="$1"
VERSION="${VERSION_TAG#v}"  # Remove 'v' prefix
CASK_FILE="Casks/meety.rb"

if [[ ! -f "$CASK_FILE" ]]; then
    echo "Error: $CASK_FILE not found"
    exit 1
fi

echo "Updating $CASK_FILE to version $VERSION..."

# Download the DMG to calculate SHA256
DMG_URL="https://github.com/florianchevallier/meeting-recorder/releases/download/${VERSION_TAG}/MeetingRecorder-${VERSION}.dmg"

echo "Downloading DMG to calculate SHA256..."
if ! curl -sL "$DMG_URL" -o "/tmp/MeetingRecorder-${VERSION}.dmg"; then
    echo "Error: Failed to download DMG from $DMG_URL"
    echo "Make sure the release is published first"
    exit 1
fi

NEW_SHA256=$(shasum -a 256 "/tmp/MeetingRecorder-${VERSION}.dmg" | awk '{print $1}')
rm -f "/tmp/MeetingRecorder-${VERSION}.dmg"

echo "New SHA256: $NEW_SHA256"

# Update the cask file
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"
sed -i '' "s/sha256 \".*\"/sha256 \"$NEW_SHA256\"/" "$CASK_FILE"

echo "✅ Formula updated successfully!"
echo "Version: $VERSION"
echo "SHA256: $NEW_SHA256"