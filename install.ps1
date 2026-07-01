# install.ps1
# Installs hjagar dev-tools scripts to $HOME\.hjagar\dev-tools and adds them to PATH.

$installDir = Join-Path $HOME '.hjagar\dev-tools'
$baseUrl = 'https://raw.githubusercontent.com/hjagar/dev-tools/main'
$scripts = @(
    'Remove-GitLocalBranches.ps1',
    'Remove-GitLocalBranches.sh',
    'setup.ps1',
    'setup.sh',
    'uninstall.ps1',
    'uninstall.sh'
)

Write-Host "Installing hjagar/dev-tools to $installDir ..." -ForegroundColor Cyan

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "  Created $installDir" -ForegroundColor Green
}

foreach ($script in $scripts) {
    $dest = Join-Path $installDir $script
    $url = "$baseUrl/$script"
    Write-Host "  Downloading $script ..."
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# Add to user PATH (permanent, registry)
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$installDir", 'User')
    Write-Host "`nAdded $installDir to user PATH (permanent)." -ForegroundColor Green
} else {
    Write-Host "`n$installDir already in PATH." -ForegroundColor Yellow
}

# Also add to current $PROFILE for this session
$profileLine = "`$env:PATH += `";$installDir`""
if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -notlike "*$installDir*") {
        Add-Content $PROFILE "`n# hjagar dev-tools`n$profileLine"
        Write-Host "Added to $PROFILE." -ForegroundColor Green
    }
} else {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Set-Content $PROFILE "# hjagar dev-tools`n$profileLine"
    Write-Host "Created $PROFILE with PATH entry." -ForegroundColor Green
}

Write-Host "`nDone. Restart your terminal or run: . `$PROFILE" -ForegroundColor Cyan
