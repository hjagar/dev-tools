# dev-tools-setup.ps1
# Creates or updates .git-tools.json in the current repo root.

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Host "Error: not inside a git repository." -ForegroundColor Red
    exit 1
}
$repoRoot = $repoRoot.Trim()
$configPath = Join-Path $repoRoot '.git-tools.json'

if (Test-Path $configPath) {
    $existing = Get-Content $configPath -Raw
    Write-Host "Existing .git-tools.json found:" -ForegroundColor Yellow
    Write-Host $existing
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Gray
        exit 0
    }
}

$input = Read-Host "Protected branches (comma-separated, default: main,develop)"
if ([string]::IsNullOrWhiteSpace($input)) {
    $branches = @('main', 'develop')
} else {
    $branches = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

$config = [ordered]@{ protectedBranches = $branches }
$config | ConvertTo-Json -Depth 2 | Set-Content $configPath -Encoding UTF8

Write-Host "`nCreated $configPath" -ForegroundColor Green
Write-Host "Protected branches: $($branches -join ', ')"
