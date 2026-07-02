param (
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$ReleaseType,

    [Parameter(Mandatory=$false)]
    [switch]$LocalOnly,

    [Parameter(Mandatory=$false)]
    [switch]$SkipTest,

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Write-Host "=== hdv-release-project ===" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. PRE-FLIGHT CHECKS
# -------------------------------------------------------------
Write-Host "`n[1/5] Running pre-flight checks..." -ForegroundColor Cyan

# Check if git is clean
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Error "Error: Working directory has uncommitted changes. Please commit or stash them first."
    exit 1
}

# Check if package.json exists
if (-not (Test-Path 'package.json')) {
    Write-Error "Error: Unsupported project type. No package.json found."
    exit 1
}

Write-Host "  Pre-flight checks passed." -ForegroundColor Green

# -------------------------------------------------------------
# 2. QUALITY GATE
# -------------------------------------------------------------
Write-Host "`n[2/5] Running Quality Gates..." -ForegroundColor Cyan
$package = Get-Content -Raw 'package.json' | ConvertFrom-Json

# Run Test if defined and not skipped
if (-not $SkipTest -and $package.scripts.test -and $package.scripts.test -notmatch 'no test specified') {
    Write-Host "  Running test script (npm test)..." -ForegroundColor Gray
    npm test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: npm test failed. Aborting release."
        exit 1
    }
} else {
    Write-Host "  Skipping tests (no script defined or -SkipTest active)." -ForegroundColor Yellow
}

# Run Build if defined and not skipped
if (-not $SkipBuild -and $package.scripts.build) {
    Write-Host "  Running build script (npm run build)..." -ForegroundColor Gray
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: npm run build failed. Aborting release."
        exit 1
    }
} else {
    Write-Host "  Skipping build (no script defined or -SkipBuild active)." -ForegroundColor Yellow
}

Write-Host "  Quality gates passed successfully." -ForegroundColor Green

# -------------------------------------------------------------
# 3. VERSION BUMP
# -------------------------------------------------------------
Write-Host "`n[3/5] Bumping version and generating changelog..." -ForegroundColor Cyan
npx standard-version --release-as $ReleaseType
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: npx standard-version failed. Aborting release."
    exit 1
}

# Read version tag
$package = Get-Content -Raw 'package.json' | ConvertFrom-Json
$versionTag = "v" + $package.version
Write-Host "  Local version bumped to $versionTag" -ForegroundColor Green

# -------------------------------------------------------------
# 4. GIT PUSH
# -------------------------------------------------------------
if ($LocalOnly) {
    Write-Host "`n[SWITCH] LocalOnly is active. Skipping remote push and GitHub release." -ForegroundColor Yellow
    Write-Host "Done. Release $versionTag completed locally." -ForegroundColor Green
    exit 0
}

Write-Host "`n[4/5] Pushing tags and commits to remote..." -ForegroundColor Cyan
$activeBranch = (git branch --show-current).Trim()
git push origin $activeBranch --follow-tags
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: git push failed. Aborting release."
    exit 1
}
Write-Host "  Pushed to origin/$activeBranch successfully." -ForegroundColor Green

# -------------------------------------------------------------
# 5. GITHUB RELEASE
# -------------------------------------------------------------
Write-Host "`n[5/5] Creating GitHub release..." -ForegroundColor Cyan
gh release create $versionTag --title "Release $versionTag" --generate-notes
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: gh release create failed."
    exit 1
}

Write-Host "`nDone. Release $versionTag published successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
