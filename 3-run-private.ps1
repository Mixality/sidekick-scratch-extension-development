# PowerShell version of 3-run-private.sh
$ErrorActionPreference = "Stop"

Write-Host "=== STARTING SCRATCH TEST SERVER ===" -ForegroundColor Cyan

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildPath = Join-Path $SCRIPT_DIR "scratch-gui\build"

if (-not (Test-Path $buildPath)) {
    Write-Host "ERROR: Build directory not found. Run .\2-build.ps1 first!" -ForegroundColor Red
    exit 1
}

$port = 8000
Write-Host "Starting HTTP server on port $port..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Open your browser at: http://localhost:$port" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Try Python first, then fallback to Node.js http-server
try {
    python -m http.server $port --directory $buildPath
} catch {
    Write-Host "Python not found, trying Node.js http-server..." -ForegroundColor Yellow
    
    # Check if http-server is installed
    $httpServer = Get-Command http-server -ErrorAction SilentlyContinue
    if (-not $httpServer) {
        Write-Host "Installing http-server..." -ForegroundColor Yellow
        npm install -g http-server
    }
    
    http-server $buildPath -p $port
}
