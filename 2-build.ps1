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

Write-Host "Building Scratch VM..." -ForegroundColor Yellow
Set-Location "scratch-vm"
$env:NODE_OPTIONS = "--openssl-legacy-provider"
npm run build
Set-Location ..

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

Write-Host ""
Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Green
Write-Host "Run .\3-run-private.ps1 to test your extension" -ForegroundColor Cyan
