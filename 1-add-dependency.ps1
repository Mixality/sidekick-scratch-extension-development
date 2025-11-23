# PowerShell version of 1-add-dependency.sh
# ./1-add-dependency.ps1 [module-name]
# 
# 1.: Tries: "npm install [module-name]"
# 2.: Checks if module has Node.js-specific dependencies
# --> 2.1.: If module has Node.js dependency: Downloads browser-compatible version automatically
# --> 2.2.: If it works: Remains as npm dependency
# 
# Examples:
# .\1-add-dependency.ps1 syllable
# --> ✓ Works with npm --> remains as dependency
# 
# .\1-add-dependency.ps1 mqtt
# --> ⚠ Has Node.js dependencies
# --> Automatically downloads browser-compatible version
# 
# .\1-add-dependency.ps1 axios
# --> ✓ Might work with npm OR
# --> Downloads browser version (depending)

$ErrorActionPreference = "Stop"

$MODULE = $args[0]

if (-not $MODULE) {
    Write-Host "Usage: .\1-add-dependency.ps1 <module-name>" -ForegroundColor Red
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\1-add-dependency.ps1 syllable  # npm package"
    Write-Host "  .\1-add-dependency.ps1 mqtt      # browser version"
    exit 1
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Checking that Scratch has been set up..." -ForegroundColor Yellow
if (-not (Test-Path "$SCRIPT_DIR\patched")) {
    Write-Host "ERROR: Scratch has not yet been set up. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

Write-Host "Adding new dependency: $MODULE" -ForegroundColor Cyan
Write-Host ""

$scratchVmPath = Join-Path $SCRIPT_DIR "scratch-vm"
Set-Location $scratchVmPath

# Try to install as npm dependency
Write-Host "Attempting to install via npm..." -ForegroundColor Yellow
try {
    npm install --save $MODULE 2>&1 | Out-Null
    $npmSuccess = $LASTEXITCODE -eq 0
} catch {
    $npmSuccess = $false
}

if ($npmSuccess) {
    Write-Host "✓ Successfully installed $MODULE as npm dependency" -ForegroundColor Green
    Write-Host ""
    
    # Check if the module has Node.js-specific dependencies
    Write-Host "Checking if $MODULE has Node.js-specific dependencies..." -ForegroundColor Yellow
    
    # Get the package's dependencies
    $packageInfoJson = npm view $MODULE dependencies --json 2>$null
    if (-not $packageInfoJson) {
        $packageInfoJson = "{}"
    }
    
    # List of Node.js core modules that indicate it's Node-only
    $nodejsCoreModules = @(
        "fs", "net", "tls", "http", "https", "dgram", "child_process", "cluster", 
        "os", "stream", "crypto", "dns", "process", "buffer", "url", "path", 
        "querystring", "util", "events", "zlib", "readline", "repl", "vm", 
        "domain", "assert", "constants", "punycode", "string_decoder", "sys", 
        "timers", "tty", "http2"
    )
    
    # Check if package depends on Node.js core modules
    $hasNodeDependency = $false
    $foundModules = @()
    
    foreach ($coreModule in $nodejsCoreModules) {
        if ($packageInfoJson -match "`"$coreModule`"") {
            $hasNodeDependency = $true
            $foundModules += $coreModule
        }
    }
    
    if ($hasNodeDependency) {
        Write-Host ""
        Write-Host "⚠ WARNING: $MODULE depends on Node.js core modules:" -ForegroundColor Yellow
        $foundModules | Select-Object -First 5 | Sort-Object -Unique | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Yellow
        }
        Write-Host "This package likely won't work in the browser!" -ForegroundColor Yellow
        Write-Host "Attempting to download browser-compatible version instead..." -ForegroundColor Yellow
        Write-Host ""
        
        # Remove the npm package since it won't work
        npm uninstall $MODULE | Out-Null
        
        # Download browser version using the other script
        Set-Location $SCRIPT_DIR
        & "$SCRIPT_DIR\1-2-add-thirdparty-library.ps1" $MODULE
    } else {
        Write-Host "✓ $MODULE appears to be browser-compatible!" -ForegroundColor Green
        Write-Host "Note: If you encounter issues, you can manually install the browser version with:" -ForegroundColor Cyan
        Write-Host "  .\1-2-add-thirdparty-library.ps1 $MODULE" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "⚠ npm install failed for $MODULE" -ForegroundColor Yellow
    Write-Host "Attempting to download browser-compatible version instead..." -ForegroundColor Yellow
    Write-Host ""
    
    Set-Location $SCRIPT_DIR
    & "$SCRIPT_DIR\1-2-add-thirdparty-library.ps1" $MODULE
}
