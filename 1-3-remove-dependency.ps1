# PowerShell version of 1-3-remove-dependency.sh
# Removes npm dependencies or third-party libraries

$ErrorActionPreference = "Stop"

$MODULE = $args[0]

if (-not $MODULE) {
    Write-Host "Usage: .\1-3-remove-dependency.ps1 <module-name>" -ForegroundColor Red
    exit 1
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Checking that Scratch has been set up..." -ForegroundColor Yellow
if (-not (Test-Path "$SCRIPT_DIR\patched")) {
    Write-Host "ERROR: Scratch has not yet been set up. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

Write-Host "Removing dependency: $MODULE" -ForegroundColor Cyan
Write-Host ""

# Check if it's an npm dependency
$NPM_INSTALLED = $false
$packageJsonPath = Join-Path $SCRIPT_DIR "scratch-vm\package.json"
if (Test-Path $packageJsonPath) {
    $packageContent = Get-Content $packageJsonPath -Raw
    if ($packageContent -match "`"$MODULE`"") {
        $NPM_INSTALLED = $true
    }
}

# Check if it's a third-party library
$THIRDPARTY_EXISTS = $false
$thirdPartyPath = Join-Path $SCRIPT_DIR "sidekick-thirdparty-libraries\$MODULE"
if (Test-Path $thirdPartyPath) {
    $THIRDPARTY_EXISTS = $true
}

# Remove npm dependency if it exists
if ($NPM_INSTALLED) {
    Write-Host "Removing $MODULE from npm dependencies..." -ForegroundColor Yellow
    Set-Location (Join-Path $SCRIPT_DIR "scratch-vm")
    npm uninstall $MODULE | Out-Null
    Write-Host "✓ Removed $MODULE from npm dependencies" -ForegroundColor Green
}

# Remove third-party library if it exists
if ($THIRDPARTY_EXISTS) {
    Write-Host "Removing $MODULE from third-party libraries..." -ForegroundColor Yellow
    Remove-Item $thirdPartyPath -Recurse -Force
    Write-Host "✓ Removed sidekick-thirdparty-libraries\$MODULE" -ForegroundColor Green
}

# Check if anything was removed
if (-not $NPM_INSTALLED -and -not $THIRDPARTY_EXISTS) {
    Write-Host ""
    Write-Host "⚠ WARNING: $MODULE was not found as npm dependency or third-party library" -ForegroundColor Yellow
    Write-Host "Nothing was removed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✓ Successfully removed $MODULE!" -ForegroundColor Green
Write-Host "Note: You may need to rebuild with .\2-build.ps1" -ForegroundColor Cyan
