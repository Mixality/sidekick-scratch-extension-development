# PowerShell version of 1-2-add-thirdparty-library.sh
# Downloads browser-compatible versions of libraries from unpkg.com

$ErrorActionPreference = "Stop"

$LIBRARY = $args[0]

if (-not $LIBRARY) {
    Write-Host "Usage: .\1-2-add-thirdparty-library.ps1 <library-name>" -ForegroundColor Red
    Write-Host "Supported libraries: mqtt, and others available on unpkg.com" -ForegroundColor Cyan
    exit 1
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Checking that Scratch has been set up..." -ForegroundColor Yellow
if (-not (Test-Path "$SCRIPT_DIR\patched")) {
    Write-Host "ERROR: Scratch has not yet been set up. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

Write-Host "Adding third-party library: $LIBRARY" -ForegroundColor Cyan
Write-Host ""

# Create the thirdparty libraries directory if it doesn't exist
$libDir = Join-Path $SCRIPT_DIR "sidekick-thirdparty-libraries\$LIBRARY"
if (-not (Test-Path $libDir)) {
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
}

# Try to download the minified browser version from unpkg
Write-Host "Downloading $LIBRARY browser library from unpkg..." -ForegroundColor Yellow

$DOWNLOADED = $false

# Try common patterns for browser builds
$PATTERNS = @(
    "dist/$LIBRARY.min.js",
    "dist/browser/$LIBRARY.min.js",
    "dist/$LIBRARY.browser.min.js",
    "build/$LIBRARY.min.js",
    "$LIBRARY.min.js"
)

foreach ($PATTERN in $PATTERNS) {
    if (-not $DOWNLOADED) {
        $URL = "https://unpkg.com/$LIBRARY@latest/$PATTERN"
        Write-Host "Trying: $URL" -ForegroundColor Gray
        
        try {
            $outputFile = Join-Path $libDir "$LIBRARY.min.js"
            Invoke-WebRequest -Uri $URL -OutFile $outputFile -ErrorAction Stop | Out-Null
            
            # Check if file is valid (not an error page)
            $content = Get-Content $outputFile -Raw
            if ($content.Length -gt 100 -and -not ($content -match "Cannot find package")) {
                Write-Host "✓ Successfully downloaded from $PATTERN" -ForegroundColor Green
                $DOWNLOADED = $true
                break
            } else {
                Remove-Item $outputFile -ErrorAction SilentlyContinue
            }
        } catch {
            # Continue to next pattern
        }
    }
}

if (-not $DOWNLOADED) {
    Write-Host ""
    Write-Host "ERROR: Could not automatically download $LIBRARY" -ForegroundColor Red
    Write-Host "Please manually download the browser-compatible version and place it in:" -ForegroundColor Yellow
    Write-Host "  sidekick-thirdparty-libraries\$LIBRARY\$LIBRARY.min.js" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Common sources:" -ForegroundColor Yellow
    Write-Host "  - https://unpkg.com/$LIBRARY" -ForegroundColor Cyan
    Write-Host "  - https://cdn.jsdelivr.net/npm/$LIBRARY" -ForegroundColor Cyan
    Write-Host "  - The package's GitHub releases page" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "✓ Third-party library '$LIBRARY' has been added successfully!" -ForegroundColor Green
Write-Host "The library will be automatically copied during the build process (.\2-build.ps1)" -ForegroundColor Cyan
Write-Host ""
Write-Host "To use it in your extension, load it in your HTML or reference it via:" -ForegroundColor Yellow
Write-Host "  /sidekick-thirdparty-libraries/$LIBRARY/$LIBRARY.min.js" -ForegroundColor Cyan
