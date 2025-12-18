# PowerShell Skript zum kompletten Neuaufbau
$ErrorActionPreference = "Stop"

Write-Host "=== COMPLETE REBUILD ===" -ForegroundColor Cyan
Write-Host "This will clean and rebuild everything from scratch" -ForegroundColor Yellow
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

# Remove old build artifacts
Write-Host "Cleaning old builds..." -ForegroundColor Yellow
if (Test-Path "scratch-gui\build") {
    Remove-Item "scratch-gui\build" -Recurse -Force
    Write-Host "  ✓ Removed scratch-gui/build" -ForegroundColor Green
}

if (Test-Path "scratch-vm\dist") {
    Remove-Item "scratch-vm\dist" -Recurse -Force
    Write-Host "  ✓ Removed scratch-vm/dist" -ForegroundColor Green
}

# Clean node_modules cache (optional but helps with issues)
Write-Host ""
Write-Host "Cleaning node caches..." -ForegroundColor Yellow
Set-Location "scratch-vm"
if (Test-Path "node_modules\.cache") {
    Remove-Item "node_modules\.cache" -Recurse -Force -ErrorAction SilentlyContinue
}
Set-Location ".."

Set-Location "scratch-gui"
if (Test-Path "node_modules\.cache") {
    Remove-Item "node_modules\.cache" -Recurse -Force -ErrorAction SilentlyContinue
}
Set-Location ".."

Write-Host "  ✓ Caches cleaned" -ForegroundColor Green

# Ensure extensions are properly linked/copied
Write-Host ""
Write-Host "Syncing extension files..." -ForegroundColor Yellow

# SIDEKICK MQTT Extension
$sourceExt1 = Join-Path $SCRIPT_DIR "sidekick-scratch-mqtt-extension"
$targetExt1 = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekickmqtt"
if (Test-Path $targetExt1) {
    Remove-Item $targetExt1 -Recurse -Force
}
Copy-Item $sourceExt1 $targetExt1 -Recurse -Force
Write-Host "  ✓ SIDEKICK MQTT extension copied" -ForegroundColor Green

# SIDEKICK Extension
$sourceExt2 = Join-Path $SCRIPT_DIR "sidekick-scratch-extension"
$targetExt2 = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\scratch3_sidekick"
if (Test-Path $targetExt2) {
    Remove-Item $targetExt2 -Recurse -Force
}
Copy-Item $sourceExt2 $targetExt2 -Recurse -Force
Write-Host "  ✓ SIDEKICK extension copied" -ForegroundColor Green

# Copy extension icons to scratch-gui src folder
Write-Host ""
Write-Host "Copying extension icons to scratch-gui..." -ForegroundColor Yellow

# MQTT Icons
$mqttIconSrc = Join-Path $SCRIPT_DIR "patches\extensions\sidekickmqtt"
$mqttIconDest = Join-Path $SCRIPT_DIR "scratch-gui\src\lib\libraries\extensions\sidekickmqtt"
if (-not (Test-Path $mqttIconDest)) {
    New-Item -ItemType Directory -Path $mqttIconDest -Force | Out-Null
}
Copy-Item "$mqttIconSrc\*" -Destination $mqttIconDest -Force
Write-Host "  ✓ MQTT icons copied" -ForegroundColor Green

# SIDEKICK Icons
$sidekickIconSrc = Join-Path $SCRIPT_DIR "patches\extensions\sidekick"
$sidekickIconDest = Join-Path $SCRIPT_DIR "scratch-gui\src\lib\libraries\extensions\sidekick"
if (-not (Test-Path $sidekickIconDest)) {
    New-Item -ItemType Directory -Path $sidekickIconDest -Force | Out-Null
}
Copy-Item "$sidekickIconSrc\*" -Destination $sidekickIconDest -Force
Write-Host "  ✓ SIDEKICK icons copied" -ForegroundColor Green

# Now run the build
Write-Host ""
Write-Host "Starting build..." -ForegroundColor Cyan
& "$SCRIPT_DIR\2-build.ps1"

Write-Host ""
Write-Host "=== REBUILD COMPLETE ===" -ForegroundColor Green
Write-Host "You can now run: .\3-run-private.ps1" -ForegroundColor Cyan
