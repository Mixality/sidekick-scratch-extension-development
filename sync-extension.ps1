# Synchronisiert die Extension-Dateien
# Kopiert von sidekick-scratch-extension/ nach scratch-vm/src/extensions/sidekick-scratch-extension/

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

$SOURCE = Join-Path $SCRIPT_DIR "sidekick-scratch-extension"
$TARGET = Join-Path $SCRIPT_DIR "scratch-vm\src\extensions\sidekick-scratch-extension"

if (-not (Test-Path $TARGET)) {
    Write-Host "ERROR: Target directory does not exist. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

Write-Host "Synchronizing extension files..." -ForegroundColor Yellow
Write-Host "  From: $SOURCE" -ForegroundColor Gray
Write-Host "  To:   $TARGET" -ForegroundColor Gray

# Copy all files from source to target
Copy-Item "$SOURCE\*" -Destination $TARGET -Recurse -Force

Write-Host "✓ Extension files synchronized!" -ForegroundColor Green
Write-Host "Don't forget to run .\2-build.ps1 to rebuild!" -ForegroundColor Cyan
