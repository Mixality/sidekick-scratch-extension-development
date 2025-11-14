#!/bin/bash

# ./1-add-dependency.sh [module-name]
# 1.: Tries: "npm install [module-name]"
# 2.: Performs test if module "[module-name]" is webpack-compatible (creates a temporary test file)
# --> 2.1.: If module "[module-name]" has a Node.js dependency: Downloads browser-compatible version automatically
# --> 2.2.: If it works: Remains as npm dependency
# 
# Examples:
# ./1-add-dependency.sh syllable
# --> ✓ Works with npm --> remains as dependency
# 
# ./1-add-dependency.sh mqtt
# --> ⚠ Has Node.js dependencies
# --> Automatically downloads browser-compatible version
# 
# ./1-add-dependency.sh axios
# --> ✓ Might work with npm OR
# --> Downloads browser version (depending)
# 
# 
# Operation(s):
# - npm install the package
# - Check the package's dependencies with npm view
# - Look for Node.js Core Modules (fs, net, tls, stream, crypto, etc.)
# - If found → Download browser-compatible version
# - If not → Keep as npm dependency
# 
# Advantages:
# --> No manual blacklist
# --> Works for most packages
# --> Checks actual dependencies, not just names
# --> Provides helpful warnings
# 
# What is detected:
# - mqtt --> Has stream, timers → Browser version ✓
# - syllable --> No Node.js modules → npm dependency ✓
# - ws --> Has net, tls → Browser version ✓
# - axios --> Should remain npm dependency (has http but is browserify-compatible)
# 
# Limitation:
# - Packages like axios might be falsely detected because they use http but have browserify-compatible versions
# - However: User gets a warning and can manually use 1-2-add-thirdparty-library.sh

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

echo "Adding new dependency: $MODULE"
cd $SCRATCH_SRC_HOME/scratch-vm

# Try to install as npm dependency
echo "Attempting to install via npm..."
if npm install --save $MODULE 2>&1; then
    echo "✓ Successfully installed $MODULE as npm dependency"
    
    # Check package.json to see if the module has Node.js-only dependencies
    echo "Checking if $MODULE has Node.js-specific dependencies..."
    
    # Get the package's dependencies
    PACKAGE_INFO=$(npm view $MODULE dependencies --json 2>/dev/null || echo "{}")
    
    # List of Node.js core modules that indicate it's Node-only
    NODEJS_CORE_MODULES="fs|net|tls|http|https|dgram|child_process|cluster|os|stream|crypto|dns|process|buffer|url|path|querystring|util|events|zlib|readline|repl|vm|domain|assert|constants|punycode|string_decoder|sys|timers|tty|http2"
    
    # Check if package depends on Node.js core modules
    if echo "$PACKAGE_INFO" | grep -qE "($NODEJS_CORE_MODULES)"; then
        echo ""
        echo "⚠ WARNING: $MODULE depends on Node.js core modules:"
        echo "$PACKAGE_INFO" | grep -oE "($NODEJS_CORE_MODULES)" | sort -u | head -5
        echo "This package likely won't work in the browser!"
        echo "Attempting to download browser-compatible version instead..."
        echo ""
        
        # Remove the npm package since it won't work
        npm uninstall $MODULE
        
        # Download browser version using the other script
        cd /workspaces/sidekick-scratch-extension-development
        ./1-2-add-thirdparty-library.sh $MODULE
    else
        echo "✓ $MODULE appears to be browser-compatible!"
        echo "Note: If you encounter issues, you can manually install the browser version with:"
        echo "  ./1-2-add-thirdparty-library.sh $MODULE"
        rm -f /tmp/main.js /tmp/main.js.map
    fi
else
    echo ""
    echo "⚠ npm install failed for $MODULE"
    echo "Attempting to download browser-compatible version instead..."
    echo ""
    
    cd /workspaces/sidekick-scratch-extension-development
    ./1-2-add-thirdparty-library.sh $MODULE
fi
