#!/bin/bash
set -e

echo "Verifying location of Scratch source is known"
if [ -z "$SCRATCH_SRC_HOME" ]; then
    echo "Error: SCRATCH_SRC_HOME environment variable is not set."
    exit 1
fi

# Patch player.jsx with Kiosk support BEFORE building
echo "Patching player.jsx with Kiosk support..."
if [ -f "/workspaces/sidekick-scratch-extension-development/patches/player.jsx" ]; then
    cp /workspaces/sidekick-scratch-extension-development/patches/player.jsx $SCRATCH_SRC_HOME/scratch-gui/src/playground/player.jsx
    echo "✓ player.jsx patched!"
fi

echo "BUILDING SCRATCH VM ..."
cd $SCRATCH_SRC_HOME/scratch-vm
NODE_OPTIONS='--openssl-legacy-provider' ./node_modules/.bin/webpack --bail

echo "BUILDING SCRATCH GUI ..."
cd $SCRATCH_SRC_HOME/scratch-gui
NODE_OPTIONS='--openssl-legacy-provider' ./node_modules/.bin/webpack --bail

echo "Copying third-party libraries to build directory..."
if [ -d "/workspaces/sidekick-scratch-extension-development/sidekick-thirdparty-libraries" ]; then
    mkdir -p $SCRATCH_SRC_HOME/scratch-gui/build/sidekick-thirdparty-libraries
    cp -r /workspaces/sidekick-scratch-extension-development/sidekick-thirdparty-libraries/* $SCRATCH_SRC_HOME/scratch-gui/build/sidekick-thirdparty-libraries/
    echo "✓ Third-party libraries copied successfully!"
else
    echo "No third-party libraries found to copy."
fi

# Copy kiosk.html for display mode
echo "Copying kiosk.html..."
if [ -f "/workspaces/sidekick-scratch-extension-development/src/kiosk.html" ]; then
    cp /workspaces/sidekick-scratch-extension-development/src/kiosk.html $SCRATCH_SRC_HOME/scratch-gui/build/kiosk.html
    echo "✓ Kiosk display page copied!"
fi
