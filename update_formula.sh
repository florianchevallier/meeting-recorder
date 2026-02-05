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
DMG_URL="https://github.com/florianchevallier/meeting-recorder/releases/download/${VERSION_TAG}/Meety-${VERSION}.dmg"
DMG_TEMP="/tmp/Meety-${VERSION}.dmg"

echo "Downloading DMG to calculate SHA256..."
echo "URL: $DMG_URL"

# Wait for GitHub CDN to propagate the file (important after fresh release)
echo "Waiting 10 seconds for GitHub CDN propagation..."
sleep 10

# Retry logic with exponential backoff
MAX_RETRIES=5
RETRY_COUNT=0
DOWNLOAD_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        WAIT_TIME=$((2 ** RETRY_COUNT))
        echo "Retry $RETRY_COUNT/$MAX_RETRIES - waiting ${WAIT_TIME}s..."
        sleep $WAIT_TIME
    fi

    if curl -sL "$DMG_URL" -o "$DMG_TEMP"; then
        # Verify file was actually downloaded and has reasonable size
        FILE_SIZE=$(stat -f%z "$DMG_TEMP" 2>/dev/null || stat -c%s "$DMG_TEMP" 2>/dev/null)

        if [ "$FILE_SIZE" -gt 1000000 ]; then  # At least 1MB
            echo "✅ Downloaded successfully ($FILE_SIZE bytes)"
            DOWNLOAD_SUCCESS=true
            break
        else
            echo "⚠️  Downloaded file is too small ($FILE_SIZE bytes), retrying..."
            rm -f "$DMG_TEMP"
        fi
    else
        echo "⚠️  Download failed, retrying..."
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo "❌ Error: Failed to download DMG after $MAX_RETRIES attempts"
    echo "Make sure the release is published and accessible at: $DMG_URL"
    exit 1
fi

NEW_SHA256=$(shasum -a 256 "$DMG_TEMP" | awk '{print $1}')
rm -f "$DMG_TEMP"

echo "New SHA256: $NEW_SHA256"

# Get old SHA256 for comparison
OLD_SHA256=$(grep 'sha256' "$CASK_FILE" | sed -n 's/.*sha256 "\([^"]*\)".*/\1/p')
echo "Old SHA256: $OLD_SHA256"

# Verify SHA256 changed
if [ "$NEW_SHA256" = "$OLD_SHA256" ]; then
    echo "⚠️  Warning: SHA256 unchanged - this might indicate the DMG hasn't been updated"
    echo "If you're re-releasing the same version, this is expected."
fi

# Update the cask file
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"
sed -i '' "s/sha256 \".*\"/sha256 \"$NEW_SHA256\"/" "$CASK_FILE"

echo ""
echo "✅ Formula updated successfully!"
echo "   Version: $VERSION"
echo "   SHA256: $NEW_SHA256"
echo ""
echo "📋 Next steps:"
echo "   1. Verify the changes: git diff $CASK_FILE"
echo "   2. Test locally: brew reinstall --cask meety"
echo "   3. Commit and push: git add $CASK_FILE && git commit && git push"