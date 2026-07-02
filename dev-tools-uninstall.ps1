$installDir = Join-Path $HOME '.hjagar\dev-tools'
$profileLine = '$env:PATH += ";' + $installDir + '"'
$blockA = "`n# hjagar dev-tools`n$profileLine"
$blockB = "# hjagar dev-tools`n$profileLine"

Write-Host "Remove hjagar/dev-tools? This will delete files and edit your PowerShell profile." -ForegroundColor Cyan
$confirm = Read-Host "(y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    $newContent = $content.Replace($blockA, '').Replace($blockB, '')
    if ($newContent -ne $content) {
        Set-Content $PROFILE $newContent -NoNewline
        Write-Host "Removed block from $PROFILE" -ForegroundColor Green
    } else {
        Write-Host "No block found in $PROFILE (skip)" -ForegroundColor Yellow
    }
} else {
    Write-Host "$PROFILE not found (skip)" -ForegroundColor Yellow
}

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$parts = $userPath -split ';' | Where-Object { $_ -ne $installDir }
$newPath = $parts -join ';'
if ($newPath -ne $userPath) {
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Removed $installDir from user PATH" -ForegroundColor Green
} else {
    Write-Host "PATH entry not found (skip)" -ForegroundColor Yellow
}

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "Removed $installDir" -ForegroundColor Green
} else {
    Write-Host "Install dir not found (skip)" -ForegroundColor Yellow
}

$parent = Join-Path $HOME '.hjagar'
if ((Test-Path $parent) -and -not (Get-ChildItem $parent -Force)) {
    Remove-Item $parent -Force
    Write-Host "Removed $parent" -ForegroundColor Green
} else {
    Write-Host "$parent not empty or not found (kept)" -ForegroundColor Yellow
}

if ($PSCommandPath -and $PSCommandPath.StartsWith($installDir)) {
    if (Test-Path $PSCommandPath) {
        Remove-Item $PSCommandPath -Force
    }
} else {
    Write-Host "Running from clone - remove dev-tools-uninstall.ps1 manually if needed." -ForegroundColor Gray
}

Write-Host "`nDone. Restart your terminal to clear the PATH from the current session." -ForegroundColor Cyan
