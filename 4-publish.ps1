# PowerShell version of 4-publish.sh
# Publishes your Scratch extension to GitHub Pages

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

Write-Host "=== PUBLISHING SCRATCH EXTENSION TO GITHUB PAGES ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking that Scratch has been set up..." -ForegroundColor Yellow
if (-not (Test-Path "patched")) {
    Write-Host "ERROR: Scratch has not yet been set up. Run .\0-setup.ps1 first!" -ForegroundColor Red
    exit 1
}

Write-Host "Checking for uncommitted changes..." -ForegroundColor Yellow
git add sidekick-scratch-extension 2>$null
git add dependencies 2>$null

# Check if there are staged changes
$staged = git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m "Update" 2>$null
}

# Get current branch name
$CURRENTBRANCH = git rev-parse --abbrev-ref HEAD

# Check if current branch exists on remote and pull if needed
$remoteBranches = git ls-remote --heads origin $CURRENTBRANCH 2>$null
if ($remoteBranches -match $CURRENTBRANCH) {
    Write-Host "Pulling latest changes from origin/$CURRENTBRANCH..." -ForegroundColor Yellow
    try {
        git pull origin $CURRENTBRANCH 2>$null
    } catch {
        Write-Host "Pull failed, trying to reset to remote state..." -ForegroundColor Yellow
        git fetch origin $CURRENTBRANCH 2>$null
        git reset --hard origin/$CURRENTBRANCH 2>$null
        # Re-add and commit our changes
        git add sidekick-scratch-extension 2>$null
        git add dependencies 2>$null
        $staged = git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            git commit -m "Update" 2>$null
        }
    }
}

Write-Host "Pushing to origin/$CURRENTBRANCH..." -ForegroundColor Yellow
git push origin $CURRENTBRANCH

Write-Host ""
Write-Host "Building the Scratch fork..." -ForegroundColor Yellow
& "$SCRIPT_DIR\2-build.ps1"

Write-Host ""
Write-Host "Preparing gh-pages branch..." -ForegroundColor Yellow
$DEVBRANCH = git rev-parse --abbrev-ref HEAD

# Check if gh-pages branch exists
$branchExists = git rev-parse --verify gh-pages 2>$null
if ($LASTEXITCODE -eq 0) {
    git checkout gh-pages
    # Pull latest changes from remote gh-pages if it exists
    $remoteGhPages = git ls-remote --heads origin gh-pages 2>$null
    if ($remoteGhPages -match "gh-pages") {
        Write-Host "Pulling latest changes from remote gh-pages..." -ForegroundColor Yellow
        try {
            git pull origin gh-pages 2>$null
        } catch {
            Write-Host "Pull failed, trying to reset to remote state..." -ForegroundColor Yellow
            git fetch origin gh-pages 2>$null
            git reset --hard origin/gh-pages 2>$null
        }
    }
} else {
    git checkout -b gh-pages
}

Write-Host "Preparing publish folder..." -ForegroundColor Yellow
if (Test-Path "scratch") {
    Remove-Item -Path "scratch\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path "scratch" | Out-Null
}

Write-Host "Publishing the Scratch fork..." -ForegroundColor Yellow
$buildPath = Join-Path $SCRIPT_DIR "scratch-gui\build\*"
Copy-Item -Path $buildPath -Destination "scratch\" -Recurse -Force

git add scratch
git commit -m "Update"
git push origin gh-pages

Write-Host ""
Write-Host "=== PUBLISH COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your Scratch extension is being published to GitHub Pages!" -ForegroundColor Cyan
Write-Host "It will be available at:" -ForegroundColor Yellow
Write-Host ""

# Try to get GitHub username and repo name
try {
    $remoteUrl = git config --get remote.origin.url
    if ($remoteUrl -match "github\.com[:/](.+?)/(.+?)(\.git)?$") {
        $username = $matches[1]
        $reponame = $matches[2] -replace "\.git$", ""
        Write-Host "  https://$username.github.io/$reponame/scratch/" -ForegroundColor Green
    } else {
        Write-Host "  https://<your-username>.github.io/<your-repo>/scratch/" -ForegroundColor Green
    }
} catch {
    Write-Host "  https://<your-username>.github.io/<your-repo>/scratch/" -ForegroundColor Green
}

Write-Host ""
Write-Host "Note: It may take a few minutes for GitHub Pages to update." -ForegroundColor Yellow
Write-Host "Switching back to $DEVBRANCH branch..." -ForegroundColor Yellow
git checkout $DEVBRANCH

Write-Host ""
Write-Host "Done! 🎉" -ForegroundColor Green
