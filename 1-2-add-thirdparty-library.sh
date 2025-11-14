#!/bin/bash
set -e

LIBRARY=$1

echo "Verifying location of Scratch source is known"
if [ -z "$SCRATCH_SRC_HOME" ]; then
    echo "Error: SCRATCH_SRC_HOME environment variable is not set."
    exit 1
fi

echo "Checking that Scratch has been patched"
if [ ! -f "$SCRATCH_SRC_HOME/patched" ]; then
    echo "Scratch has not yet been patched. Run ./0-setup.sh"
    exit 1
fi

# allow this script to be run from other locations
if [[ $BASH_SOURCE = */* ]]; then
  cd -- "${BASH_SOURCE%/*}/" || exit
fi

if [ -z "$LIBRARY" ]; then
    echo "Usage: ./1-2-add-thirdparty-library.sh <library-name>"
    echo "Supported libraries: mqtt"
    exit 1
fi

echo "Adding third-party library: $LIBRARY"

# Create the thirdparty libraries directory if it doesn't exist
mkdir -p sidekick-thirdparty-libraries/$LIBRARY

# Try to download the minified browser version from unpkg
echo "Downloading $LIBRARY browser library from unpkg..."

# First, try the most common pattern: dist/*.min.js
DOWNLOADED=false

# Try common patterns for browser builds
PATTERNS=(
    "dist/$LIBRARY.min.js"
    "dist/browser/$LIBRARY.min.js"
    "dist/$LIBRARY.browser.min.js"
    "build/$LIBRARY.min.js"
    "$LIBRARY.min.js"
)

for PATTERN in "${PATTERNS[@]}"; do
    if [ "$DOWNLOADED" = false ]; then
        URL="https://unpkg.com/$LIBRARY@latest/$PATTERN"
        echo "Trying: $URL"
        
        if curl -f -L "$URL" -o "sidekick-thirdparty-libraries/$LIBRARY/$LIBRARY.min.js" 2>/dev/null; then
            echo "✓ Successfully downloaded from $PATTERN"
            DOWNLOADED=true
            break
        fi
    fi
done

if [ "$DOWNLOADED" = false ]; then
    echo ""
    echo "ERROR: Could not automatically download $LIBRARY"
    echo "Please manually download the browser-compatible version and place it in:"
    echo "  sidekick-thirdparty-libraries/$LIBRARY/$LIBRARY.min.js"
    echo ""
    echo "Common sources:"
    echo "  - https://unpkg.com/$LIBRARY"
    echo "  - https://cdn.jsdelivr.net/npm/$LIBRARY"
    echo "  - The package's GitHub releases page"
    exit 1
fi


echo ""
echo "Third-party library '$LIBRARY' has been added successfully!"
echo "The library will be automatically copied during the build process."
