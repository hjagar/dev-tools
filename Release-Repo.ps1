param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('patch','minor','major')]
    [string]$ReleaseType
)

$ErrorActionPreference = "Stop"

Write-Host "=== Release-Repo ===" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

# [1/5] Quality gate
Write-Host "[1/5] Quality gate (shellcheck)..." -ForegroundColor Cyan
if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
    Write-Host "shellcheck not found. Install: winget install koalaman.shellcheck" -ForegroundColor Red
    exit 1
}
$shFiles = Get-ChildItem -Path $repoRoot -Filter *.sh -File
foreach ($file in $shFiles) {
    Write-Host "  checking $($file.Name)..." -ForegroundColor Gray
    shellcheck $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "shellcheck failed on $($file.Name). Aborting — nothing was created." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  All shell scripts passed." -ForegroundColor Green

# [2/5] Version bump
Write-Host "[2/5] Version bump..." -ForegroundColor Cyan
$lastTag = git describe --tags --abbrev=0 2>$null
if ($lastTag) { $lastTag = $lastTag.Trim() }
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($lastTag)) {
    $nextVersion = "v1.0.0"
    Write-Host "  No existing tags. Proposing first release $nextVersion." -ForegroundColor Yellow
} else {
    $parts = $lastTag.TrimStart('v').Split('.')
    $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
    switch ($ReleaseType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }
    $nextVersion = "v$major.$minor.$patch"
    Write-Host "  $lastTag -> $nextVersion ($ReleaseType)" -ForegroundColor Green
}
$confirm = Read-Host "Create release $nextVersion? (y/N)"
if ($confirm -notin @('y','Y')) {
    Write-Host "Cancelled. Nothing was created." -ForegroundColor Gray
    exit 0
}

# [3/5] Package
Write-Host "[3/5] Packaging..." -ForegroundColor Cyan
$buildDir = Join-Path $repoRoot 'build'
$zipPath  = Join-Path $buildDir 'dev-tools.zip'
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $buildDir | Out-Null
$files = Get-ChildItem -Path $repoRoot -File |
    Where-Object { $_.Name -notmatch '^(Release-Repo\..*|CLAUDE\.md|\.git.*|install\..*)$' } |
    Select-Object -ExpandProperty FullName
Compress-Archive -Path $files -DestinationPath $zipPath -Force
Write-Host "  Created build/dev-tools.zip" -ForegroundColor Green

# [4/5] Tag + push
Write-Host "[4/5] Tag + push..." -ForegroundColor Cyan
git tag -a $nextVersion -m "Release $nextVersion"
if ($LASTEXITCODE -ne 0) { Write-Host "git tag failed." -ForegroundColor Red; exit 1 }
git push --follow-tags
if ($LASTEXITCODE -ne 0) { Write-Host "git push failed." -ForegroundColor Red; exit 1 }
Write-Host "  Tagged and pushed $nextVersion." -ForegroundColor Green

# [5/5] Publish + cleanup
Write-Host "[5/5] Publishing GitHub release..." -ForegroundColor Cyan
gh release create $nextVersion $zipPath --generate-notes
if ($LASTEXITCODE -ne 0) {
    Write-Host "gh release create failed (check 'gh auth status'). Tag $nextVersion is already pushed — re-run after auth to reuse it." -ForegroundColor Red
    exit 1
}
Remove-Item $buildDir -Recurse -Force
Write-Host "`nDone. Release $nextVersion published." -ForegroundColor Green
