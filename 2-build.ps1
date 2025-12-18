# PowerShell version of 2-build.sh
$ErrorActionPreference = "Stop"

Write-Host "=== BUILDING SCRATCH EXTENSION ===" -ForegroundColor Cyan

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

# Check if setup was run
if (-not (Test-Path "scratch-vm")) {
    Write-Host "ERROR: Scratch source not found. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

# Sync extension files first
Write-Host "Synchronizing MQTT extension files..." -ForegroundColor Yellow
$sourceExt = Join-Path $SCRIPT_DIR "sidekick-scratch-mqtt-extension"
$targetExt = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekickmqtt"
if (Test-Path $targetExt) {
    Copy-Item "$sourceExt\*" -Destination $targetExt -Recurse -Force
    Write-Host "✓ MQTT extension files synchronized!" -ForegroundColor Green
}

Write-Host "Synchronizing SIDEKICK extension files..." -ForegroundColor Yellow
$sourceExt2 = Join-Path $SCRIPT_DIR "sidekick-scratch-extension"
$targetExt2 = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekick"
if (Test-Path $targetExt2) {
    Copy-Item "$sourceExt2\*" -Destination $targetExt2 -Recurse -Force
    Write-Host "✓ SIDEKICK extension files synchronized!" -ForegroundColor Green
}

# Patch player.jsx with Kiosk support BEFORE building
$playerPatch = Join-Path $SCRIPT_DIR "patches\player.jsx"
$playerTarget = Join-Path $SCRIPT_DIR "scratch-gui\src\playground\player.jsx"
if (Test-Path $playerPatch) {
    Write-Host "Patching player.jsx with Kiosk support..." -ForegroundColor Yellow
    Copy-Item $playerPatch $playerTarget -Force
    Write-Host "✓ player.jsx patched!" -ForegroundColor Green
}

Write-Host "Building Scratch VM..." -ForegroundColor Yellow
Set-Location "scratch-vm"
$env:NODE_OPTIONS = "--openssl-legacy-provider"
npm run build
Set-Location ..

Write-Host "Linking scratch-vm to scratch-gui..." -ForegroundColor Yellow
Set-Location "scratch-vm"
npm link
Set-Location ..
Set-Location "scratch-gui"
npm link scratch-vm
Set-Location ..
Write-Host "✓ scratch-vm linked!" -ForegroundColor Green

Write-Host "Building Scratch GUI..." -ForegroundColor Yellow
Set-Location "scratch-gui"
$env:NODE_OPTIONS = "--openssl-legacy-provider"
npm run build
Set-Location ..

# Copy third-party libraries
$thirdPartySource = Join-Path $SCRIPT_DIR "sidekick-thirdparty-libraries"
$thirdPartyTarget = Join-Path $SCRIPT_DIR "scratch-gui\build\sidekick-thirdparty-libraries"

if (Test-Path $thirdPartySource) {
    Write-Host "Copying third-party libraries..." -ForegroundColor Yellow
    if (Test-Path $thirdPartyTarget) {
        Remove-Item $thirdPartyTarget -Recurse -Force
    }
    Copy-Item $thirdPartySource $thirdPartyTarget -Recurse -Force
    Write-Host "✓ Third-party libraries copied!" -ForegroundColor Green
} else {
    Write-Host "No third-party libraries found to copy." -ForegroundColor Yellow
}

# Ensure videos folder exists with video-list.json
$videosTarget = Join-Path $SCRIPT_DIR "scratch-gui\build\videos"
if (-not (Test-Path $videosTarget)) {
    Write-Host "Creating videos folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $videosTarget -Force | Out-Null
}
# Create empty video-list.json if not exists
$videoListFile = Join-Path $videosTarget "video-list.json"
if (-not (Test-Path $videoListFile)) {
    Write-Host "Creating empty video-list.json..." -ForegroundColor Yellow
    "[]" | Out-File -FilePath $videoListFile -Encoding UTF8
}
Write-Host "✓ Videos folder ready!" -ForegroundColor Green

# Copy extension assets to build folder
Write-Host "Copying extension assets to build folder..." -ForegroundColor Yellow
$buildExtensionsPath = Join-Path $SCRIPT_DIR "scratch-gui\build\static\assets"
if (-not (Test-Path $buildExtensionsPath)) {
    New-Item -ItemType Directory -Path $buildExtensionsPath -Force | Out-Null
}

# Copy SIDEKICK MQTT icons
$mqttIconSource = Join-Path $SCRIPT_DIR "patches\extensions\sidekickmqtt"
Copy-Item "$mqttIconSource\*.png" -Destination $buildExtensionsPath -Force -ErrorAction SilentlyContinue

# Copy SIDEKICK icons
$sidekickIconSource = Join-Path $SCRIPT_DIR "patches\extensions\sidekick"
Copy-Item "$sidekickIconSource\*.svg" -Destination $buildExtensionsPath -Force -ErrorAction SilentlyContinue

Write-Host "✓ Extension assets copied to build folder!" -ForegroundColor Green

# Copy kiosk.html for display mode
$kioskSource = Join-Path $SCRIPT_DIR "src\kiosk.html"
$kioskTarget = Join-Path $SCRIPT_DIR "scratch-gui\build\kiosk.html"
if (Test-Path $kioskSource) {
    Write-Host "Copying kiosk.html..." -ForegroundColor Yellow
    Copy-Item $kioskSource $kioskTarget -Force
    Write-Host "✓ Kiosk display page copied!" -ForegroundColor Green
}

# Copy dashboard QR code
$qrSource = Join-Path $SCRIPT_DIR "src\dashboard-qr.png"
$qrTarget = Join-Path $SCRIPT_DIR "scratch-gui\build\dashboard-qr.png"
if (Test-Path $qrSource) {
    Write-Host "Copying dashboard QR code..." -ForegroundColor Yellow
    Copy-Item $qrSource $qrTarget -Force
    Write-Host "✓ Dashboard QR code copied!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Green
Write-Host "Run .\3-run-private.ps1 to test your extension" -ForegroundColor Cyan
