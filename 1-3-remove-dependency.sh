#!/bin/bash
set -e

MODULE=$1

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

if [ -z "$MODULE" ]; then
    echo "Usage: ./1-3-remove-dependency.sh <module-name>"
    exit 1
fi

echo "Removing dependency: $MODULE"

# Check if it's an npm dependency
NPM_INSTALLED=false
if [ -f "$SCRATCH_SRC_HOME/scratch-vm/package.json" ]; then
    if grep -q "\"$MODULE\"" "$SCRATCH_SRC_HOME/scratch-vm/package.json"; then
        NPM_INSTALLED=true
    fi
fi

# Check if it's a third-party library
THIRDPARTY_EXISTS=false
if [ -d "sidekick-thirdparty-libraries/$MODULE" ]; then
    THIRDPARTY_EXISTS=true
fi

# Remove npm dependency if it exists
if [ "$NPM_INSTALLED" = true ]; then
    echo "Removing $MODULE from npm dependencies..."
    cd $SCRATCH_SRC_HOME/scratch-vm
    npm uninstall $MODULE
    echo "✓ Removed $MODULE from npm dependencies"
fi

# Remove third-party library if it exists
if [ "$THIRDPARTY_EXISTS" = true ]; then
    echo "Removing $MODULE from third-party libraries..."
    rm -rf "sidekick-thirdparty-libraries/$MODULE"
    echo "✓ Removed sidekick-thirdparty-libraries/$MODULE"
fi

# Check if anything was removed
if [ "$NPM_INSTALLED" = false ] && [ "$THIRDPARTY_EXISTS" = false ]; then
    echo ""
    echo "⚠ WARNING: $MODULE was not found as npm dependency or third-party library"
    echo "Nothing was removed."
    exit 1
fi

echo ""
echo "✓ Successfully removed $MODULE!"
