# PowerShell version of 0-setup.sh
$ErrorActionPreference = "Stop"

Write-Host "=== SCRATCH EXTENSION SETUP (Windows) ===" -ForegroundColor Cyan

# Set working directory
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

# Check if scratch-vm already exists
if (Test-Path "scratch-vm") {
    Write-Host "✓ Scratch source code already downloaded" -ForegroundColor Green
} else {
    Write-Host "Downloading Scratch source code..." -ForegroundColor Yellow
    
    # Clone scratch-vm
    Write-Host "  - Cloning scratch-vm..."
    git clone --depth=1 https://github.com/LLK/scratch-vm.git
    
    # Clone scratch-gui
    Write-Host "  - Cloning scratch-gui..."
    git clone --depth=1 https://github.com/LLK/scratch-gui.git
    
    Write-Host "✓ Source code downloaded" -ForegroundColor Green
}

# Install dependencies for scratch-vm
Write-Host "Installing scratch-vm dependencies..." -ForegroundColor Yellow
Set-Location "scratch-vm"
npm install
Set-Location ..

# Install dependencies for scratch-gui
Write-Host "Installing scratch-gui dependencies..." -ForegroundColor Yellow
Set-Location "scratch-gui"
npm install
Set-Location ..

# Check if already patched
if (Test-Path "patched") {
    Write-Host "✓ Already patched, skipping patch step" -ForegroundColor Yellow
    exit 0
}

Write-Host "Applying patches..." -ForegroundColor Yellow

# Add extension symlink to scratch-vm (or copy if symlink fails)
$extensionPath = Join-Path $SCRIPT_DIR "sidekick-scratch-mqtt-extension"
$targetPath = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekickmqtt"

if (Test-Path $targetPath) {
    Write-Host "  - SIDEKICK MQTT extension already exists" -ForegroundColor Yellow
} else {
    Write-Host "  - Linking/copying SIDEKICK MQTT extension..."
    try {
        # Try to create symlink (requires admin or developer mode)
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $extensionPath -Force -ErrorAction Stop | Out-Null
        Write-Host "    ✓ Symbolic link created" -ForegroundColor Green
    } catch {
        # Fallback: copy files instead
        Write-Host "    (Symlink failed, copying files instead)" -ForegroundColor Yellow
        Copy-Item $extensionPath $targetPath -Recurse -Force
        Write-Host "    ✓ Files copied" -ForegroundColor Green
    }
}

# Add extension symlink to scratch-vm (or copy if symlink fails)
$extensionPath2 = Join-Path $SCRIPT_DIR "sidekick-scratch-extension"
$targetPath2 = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekick"

if (Test-Path $targetPath2) {
    Write-Host "  - SIDEKICK extension already exists" -ForegroundColor Yellow
} else {
    Write-Host "  - Linking/copying SIDEKICK extension..."
    try {
        # Try to create symlink (requires admin or developer mode)
        New-Item -ItemType SymbolicLink -Path $targetPath2 -Target $extensionPath2 -Force -ErrorAction Stop | Out-Null
        Write-Host "    ✓ Symbolic link created" -ForegroundColor Green
    } catch {
        # Fallback: copy files instead
        Write-Host "    (Symlink failed, copying files instead)" -ForegroundColor Yellow
        Copy-Item $extensionPath2 $targetPath2 -Recurse -Force
        Write-Host "    ✓ Files copied" -ForegroundColor Green
    }
}

# Apply scratch-vm patch
Write-Host "  - Patching scratch-vm..."
Set-Location "scratch-vm"

$extensionManagerFile = "src\extension-support\extension-manager.js"
$content = Get-Content $extensionManagerFile -Raw

# Check if already patched
if ($content -notmatch "sidekickMQTT" || $content -notmatch "sidekick") {
    # Add extension to builtinExtensions
    $content = $content -replace "(gdxfor: \(\) => require\('\.\./extensions/scratch3_gdx_for'\))", "`$1,`n    sidekickMQTT: () => require('../extensions/scratch3_sidekickmqtt'),`n    sidekick: () => require('../extensions/scratch3_sidekick')"
    Set-Content $extensionManagerFile $content -NoNewline
    Write-Host "    ✓ Extension registered in extension-manager.js" -ForegroundColor Green
} else {
    Write-Host "    ✓ Already patched" -ForegroundColor Green
}

# Move and link package.json files (or copy if symlink fails)
if (-not (Test-Path "$SCRIPT_DIR\dependencies\package.json.backup")) {
    Move-Item package.json "$SCRIPT_DIR\dependencies\package.json" -Force
    Move-Item package-lock.json "$SCRIPT_DIR\dependencies\package-lock.json" -Force
}

try {
    New-Item -ItemType SymbolicLink -Path "package.json" -Target "$SCRIPT_DIR\dependencies\package.json" -Force -ErrorAction Stop | Out-Null
    New-Item -ItemType SymbolicLink -Path "package-lock.json" -Target "$SCRIPT_DIR\dependencies\package-lock.json" -Force -ErrorAction Stop | Out-Null
} catch {
    # Fallback: hard link or copy
    Copy-Item "$SCRIPT_DIR\dependencies\package.json" "package.json" -Force
    Copy-Item "$SCRIPT_DIR\dependencies\package-lock.json" "package-lock.json" -Force
}

Set-Location ..

# Apply scratch-gui patch
Write-Host "  - Patching scratch-gui..."
Set-Location "scratch-gui"

$indexFile = "src\lib\libraries\extensions\index.jsx"
$content = Get-Content $indexFile -Raw

# Check if already patched
if ($content -notmatch "sidekick") {
    # Add imports at the top (after React import)
    $imports = @"
import sidekickMQTTIconURL from './sidekickmqtt/sidekick-mqtt.png';
import sidekickMQTTInsetIconURL from './sidekickmqtt/sidekick-mqtt-small.png';

import sidekickIconURL from './sidekick/sidekick.svg';
import sidekickInsetIconURL from './sidekick/sidekick-small.svg';

"@
    $content = $content -replace "(import \{FormattedMessage\} from 'react-intl';)", "`$1`n`n$imports"
    
    # Add extension to the export array (after "export default [")
    $extensionEntry = @"
{
        name: (
            <FormattedMessage
                defaultMessage="SIDEKICK MQTT Extension"
                description="Name for the 'SIDEKICK MQTT' extension"
                id="gui.extension.sidekickmqtt.name"
            />
        ),
        extensionId: 'sidekickMQTT',
        iconURL: sidekickMQTTIconURL,
        insetIconURL: sidekickMQTTInsetIconURL,
        description: (
            <FormattedMessage
                defaultMessage="Custom Scratch MQTT extension."
                description="Description for the 'SIDEKICK MQTT' extension"
                id="gui.extension.sidekickmqtt.description"
            />
        ),
        featured: true,
        disabled: false
    },
    {
        name: (
            <FormattedMessage
                defaultMessage="SIDEKICK Extension"
                description="Name for the 'SIDEKICK' extension"
                id="gui.extension.sidekick.name"
            />
        ),
        extensionId: 'sidekick',
        iconURL: sidekickIconURL,
        insetIconURL: sidekickInsetIconURL,
        description: (
            <FormattedMessage
                defaultMessage="SIDEKICK Scratch extension."
                description="Description for the 'SIDEKICK' extension"
                id="gui.extension.sidekick.description"
            />
        ),
        featured: true,
        disabled: false
    },
"@
    $content = $content -replace "(export default \[)", "`$1`n    $extensionEntry"
    
    Set-Content $indexFile $content -NoNewline
    Write-Host "    ✓ Extension added to GUI library" -ForegroundColor Green
} else {
    Write-Host "    ✓ Already patched" -ForegroundColor Green
}

Write-Host "Create and link SIDEKICK MQTT extension assets (or copy if symlink fails)..."
# Create and link SIDEKICK MQTT extension assets (or copy if symlink fails)
$assetsPath = "src\lib\libraries\extensions\sidekickmqtt"
if (-not (Test-Path $assetsPath)) {
    New-Item -ItemType Directory -Path $assetsPath -Force | Out-Null
}

Set-Location $assetsPath
$bgImage = Join-Path $SCRIPT_DIR "patches\extensions\sidekickmqtt\sidekick-mqtt.png"
$iconImage = Join-Path $SCRIPT_DIR "patches\extensions\sidekickmqtt\sidekick-mqtt-small.png"

try {
    if (-not (Test-Path "sidekick-mqtt.png")) {
        New-Item -ItemType SymbolicLink -Path "sidekick-mqtt.png" -Target $bgImage -Force -ErrorAction Stop | Out-Null
    }
    if (-not (Test-Path "sidekick-mqtt-small.png")) {
        New-Item -ItemType SymbolicLink -Path "sidekick-mqtt-small.png" -Target $iconImage -Force -ErrorAction Stop | Out-Null
    }
} catch {
    # Fallback: copy files
    Copy-Item $bgImage "sidekick-mqtt.png" -Force
    Copy-Item $iconImage "sidekick-mqtt-small.png" -Force
}

Set-Location $SCRIPT_DIR

Write-Host "Create and link SIDEKICK extension assets (or copy if symlink fails)..."
# Create and link SIDEKICK extension assets (or copy if symlink fails)
$assetsPath2 = "src\lib\libraries\extensions\sidekick"
if (-not (Test-Path $assetsPath2)) {
    New-Item -ItemType Directory -Path $assetsPath2 -Force | Out-Null
}

Set-Location $assetsPath2
$bgImage2 = Join-Path $SCRIPT_DIR "patches\extensions\sidekick\sidekick.svg"
$iconImage2 = Join-Path $SCRIPT_DIR "patches\extensions\sidekick\sidekick-small.svg"

try {
    if (-not (Test-Path "sidekick.svg")) {
        New-Item -ItemType SymbolicLink -Path "sidekick.svg" -Target $bgImage2 -Force -ErrorAction Stop | Out-Null
    }
    if (-not (Test-Path "sidekick-small.svg")) {
        New-Item -ItemType SymbolicLink -Path "sidekick-small.svg" -Target $iconImage2 -Force -ErrorAction Stop | Out-Null
    }
} catch {
    # Fallback: copy files
    Copy-Item $bgImage2 "sidekick.svg" -Force
    Copy-Item $iconImage2 "sidekick-small.svg" -Force
}

Set-Location $SCRIPT_DIR

# Link scratch-vm to scratch-gui (CRITICAL!)
Write-Host ""
Write-Host "Linking scratch-vm to scratch-gui..." -ForegroundColor Cyan
Set-Location "scratch-gui"
npm link ../scratch-vm
Write-Host "  ✓ scratch-gui now uses local scratch-vm" -ForegroundColor Green
Set-Location $SCRIPT_DIR

# Mark as patched
New-Item -ItemType File -Path "patched" -Force | Out-Null

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit your extension in: sidekick-scratch-extension\index.js"
Write-Host "  2. Build with: .\2-build.ps1"
Write-Host "  3. Test with: .\3-run-private.ps1"
