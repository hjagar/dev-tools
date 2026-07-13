<#
.SYNOPSIS
  Replicates a gentle-ai-managed Claude Code profile into a second profile
  directory (e.g. a CLAUDE_CONFIG_DIR-pointed folder) on this or another machine.

.DESCRIPTION
  gentle-ai (https://github.com/Gentleman-Programming/gentle-ai) always installs
  into $HOME\.claude - it resolves the target with os.UserHomeDir() + ".claude"
  hardcoded (internal/system/config_scan.go), ignoring CLAUDE_CONFIG_DIR and any
  install flag. There is no supported way to point "gentle-ai install/sync" at a
  second profile directly.

  This script copies what gentle-ai wrote into the default profile (CLAUDE.md,
  agents/, commands/, output-styles/, themes/, mcp/, .atl/, skills/) onto a
  second profile, and merges settings.json without clobbering keys the target
  already has.

  Workflow on a new machine:
    1. Install gentle-ai and run 'gentle-ai install' normally -> populates
       $HOME\.claude.
    2. Create/bootstrap the second profile directory (run `claude` once with
       CLAUDE_CONFIG_DIR pointed at it, so its own settings.json/history exist).
    3. Run this script with -TargetDir pointing at that second profile.
    4. Re-run this script after every future 'gentle-ai upgrade' / 'gentle-ai
       sync' on the source profile, to keep the second profile in step.

.PARAMETER SourceDir
  The gentle-ai-managed profile to copy from. Defaults to $HOME\.claude.

.PARAMETER TargetDir
  The profile directory to replicate into, as a full path. Takes precedence
  over -ProfileName and $env:CLAUDE_CONFIG_DIR when given.

.PARAMETER ProfileName
  Short name for a "$HOME\.claude-<name>" profile, e.g. "work" resolves to
  $HOME\.claude-work, "personal" resolves to $HOME\.claude-personal. Ignored
  if -TargetDir is also given.

.PARAMETER OverwriteConflicts
  By default, a skill that exists in both profiles with different content is
  left untouched in the target and reported as a conflict. Pass this switch to
  overwrite it with the source's version instead.

.PARAMETER WhatIf
  Preview actions without writing anything (standard PowerShell ShouldProcess).

.EXAMPLE
  .\Sync-GentleAiProfile.ps1 -ProfileName personal

.EXAMPLE
  .\Sync-GentleAiProfile.ps1 -ProfileName work -OverwriteConflicts

.EXAMPLE
  .\Sync-GentleAiProfile.ps1 -TargetDir "D:\claude-work" -WhatIf

.EXAMPLE
  # Target resolved from an already-set CLAUDE_CONFIG_DIR, no flag needed
  $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work"
  .\Sync-GentleAiProfile.ps1
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourceDir = (Join-Path $HOME ".claude"),

    [string]$TargetDir,

    [string]$ProfileName,

    [switch]$OverwriteConflicts
)

$ErrorActionPreference = 'Stop'

# Resolve the target directory: explicit -TargetDir wins, then -ProfileName
# (shorthand for $HOME\.claude-<name>), then an already-set CLAUDE_CONFIG_DIR
# in the current shell (the same env var Claude Code itself reads).
if (-not $TargetDir) {
    if ($ProfileName) {
        $TargetDir = Join-Path $HOME ".claude-$ProfileName"
    }
    elseif ($env:CLAUDE_CONFIG_DIR) {
        $TargetDir = $env:CLAUDE_CONFIG_DIR
    }
    else {
        throw "No target specified. Pass -TargetDir <path>, -ProfileName <name> (e.g. 'work' -> `$HOME\.claude-work), or set `$env:CLAUDE_CONFIG_DIR before running."
    }
}

if ((Resolve-Path -LiteralPath $SourceDir -ErrorAction SilentlyContinue).Path -eq (Resolve-Path -LiteralPath $TargetDir -ErrorAction SilentlyContinue).Path) {
    throw "SourceDir and TargetDir resolve to the same path ('$TargetDir') - nothing to sync."
}

Write-Host "Source: $SourceDir" -ForegroundColor DarkGray
Write-Host "Target: $TargetDir" -ForegroundColor DarkGray

# Directories gentle-ai owns wholesale on the source profile - safe to mirror
# byte-for-byte. 'mcp' is handled separately (Copy-McpConfigs) because its
# *.json files can embed an absolute binary path baked in for the machine
# where 'engram setup claude-code' originally ran.
$MirrorDirs = @('agents', 'commands', 'output-styles', 'themes', '.atl')

# Top-level settings.json keys we deliberately never write to the target.
# 'mcpServers' is rejected as an unrecognized field by current Claude Code
# settings validation; gentle-ai's own MCP declarations live under mcp/*.json
# instead (handled by Copy-McpConfigs), so it's safe to skip here.
$ExcludedSettingsKeys = @('mcpServers')

function Assert-GentleAiSource {
    param([string]$Path)
    foreach ($item in @('CLAUDE.md', 'skills', 'agents', 'commands')) {
        if (-not (Test-Path (Join-Path $Path $item))) {
            throw "Source '$Path' doesn't look like a gentle-ai managed profile (missing '$item'). Run 'gentle-ai install' there first."
        }
    }
}

function Copy-MirrorDir {
    param([string]$Name)
    $src = Join-Path $SourceDir $Name
    $dst = Join-Path $TargetDir $Name
    if (-not (Test-Path $src)) { return }
    if ($PSCmdlet.ShouldProcess($dst, "Mirror from $src")) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
    }
    Write-Host "  = mirrored $Name" -ForegroundColor DarkGray
}

function Copy-McpConfigs {
    # mcp/*.json can hardcode an absolute path to a helper binary (e.g. engram)
    # for whichever machine 'engram setup claude-code' last ran on. Copying
    # that path verbatim to a different machine/user breaks the MCP server
    # the moment the path doesn't exist there. Instead, resolve each command
    # against PATH on THIS machine and rewrite it - same portable pattern as
    # 'engram setup claude-code' itself would produce.
    $src = Join-Path $SourceDir 'mcp'
    $dst = Join-Path $TargetDir 'mcp'
    if (-not (Test-Path $src)) { return }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null

    Get-ChildItem -Path $src -Filter '*.json' -File | ForEach-Object {
        $config = Get-Content $_.FullName -Raw | ConvertFrom-Json -AsHashtable
        $destFile = Join-Path $dst $_.Name

        if ($config.ContainsKey('command') -and [System.IO.Path]::IsPathRooted($config.command)) {
            $binName = [System.IO.Path]::GetFileName($config.command)
            $resolved = Get-Command $binName -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($resolved) {
                if ($config.command -ne $resolved.Source) {
                    Write-Host "  ~ mcp/$($_.Name): rewrote absolute path for this machine -> $($resolved.Source)" -ForegroundColor Yellow
                }
                $config.command = $resolved.Source
            }
            else {
                Write-Warning "  ~ mcp/$($_.Name): '$binName' not found on PATH on this machine - copied as-is, this MCP server will fail to start until '$binName' is installed or the path is fixed manually."
            }
        }

        if ($PSCmdlet.ShouldProcess($destFile, "Write mcp config")) {
            ($config | ConvertTo-Json -Depth 20) | Set-Content -Path $destFile -Encoding utf8
        }
        Write-Host "  = mcp/$($_.Name)" -ForegroundColor DarkGray
    }
}

function Get-DirHashMap {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    $root = (Resolve-Path $Path).Path
    Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
        $map[$rel] = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    }
    return $map
}

function Test-DirsIdentical {
    param([string]$PathA, [string]$PathB)
    $a = Get-DirHashMap $PathA
    $b = Get-DirHashMap $PathB
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($key in $a.Keys) {
        if (-not $b.ContainsKey($key) -or $b[$key] -ne $a[$key]) { return $false }
    }
    return $true
}

function Merge-SkillsDir {
    $src = Join-Path $SourceDir 'skills'
    $dst = Join-Path $TargetDir 'skills'
    if (-not (Test-Path $src)) { return }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null

    Get-ChildItem -Path $src -Directory | ForEach-Object {
        $skillSrc = $_.FullName
        $skillDst = Join-Path $dst $_.Name

        if (-not (Test-Path $skillDst)) {
            if ($PSCmdlet.ShouldProcess($skillDst, "Add new skill")) {
                Copy-Item -Path $skillSrc -Destination $skillDst -Recurse -Force
            }
            Write-Host "  + added skill: $($_.Name)" -ForegroundColor Green
            return
        }

        if (Test-DirsIdentical -PathA $skillSrc -PathB $skillDst) {
            Write-Host "  = skill already in sync: $($_.Name)" -ForegroundColor DarkGray
            return
        }

        if ($OverwriteConflicts) {
            if ($PSCmdlet.ShouldProcess($skillDst, "Overwrite conflicting skill")) {
                Remove-Item -Path $skillDst -Recurse -Force
                Copy-Item -Path $skillSrc -Destination $skillDst -Recurse -Force
            }
            Write-Host "  ~ overwrote conflicting skill: $($_.Name)" -ForegroundColor Yellow
        }
        else {
            Write-Warning "  ~ skill '$($_.Name)' differs between source and target - left target untouched (rerun with -OverwriteConflicts to force)."
        }
    }
}

function Merge-SettingsJson {
    $srcFile = Join-Path $SourceDir 'settings.json'
    $dstFile = Join-Path $TargetDir 'settings.json'
    if (-not (Test-Path $srcFile)) { return }

    $srcJson = Get-Content $srcFile -Raw | ConvertFrom-Json -AsHashtable
    $dstJson = if (Test-Path $dstFile) {
        Get-Content $dstFile -Raw | ConvertFrom-Json -AsHashtable
    }
    else { @{} }

    foreach ($key in $srcJson.Keys) {
        if ($key -in $ExcludedSettingsKeys) { continue }

        if (-not $dstJson.ContainsKey($key)) {
            $dstJson[$key] = $srcJson[$key]
            Write-Host "  + settings.json: added '$key'" -ForegroundColor Green
            continue
        }

        if ($key -eq 'enabledPlugins' -and $dstJson[$key] -is [hashtable] -and $srcJson[$key] -is [hashtable]) {
            foreach ($pluginKey in $srcJson[$key].Keys) {
                if (-not $dstJson[$key].ContainsKey($pluginKey)) {
                    $dstJson[$key][$pluginKey] = $srcJson[$key][$pluginKey]
                    Write-Host "  + settings.json: enabledPlugins.$pluginKey" -ForegroundColor Green
                }
            }
            continue
        }

        Write-Host "  = settings.json: '$key' already present in target - left as-is" -ForegroundColor DarkGray
    }

    if ($PSCmdlet.ShouldProcess($dstFile, "Write merged settings.json")) {
        ($dstJson | ConvertTo-Json -Depth 100) | Set-Content -Path $dstFile -Encoding utf8
    }
}

# --- main ---
Assert-GentleAiSource -Path $SourceDir

if (-not (Test-Path $TargetDir)) {
    Write-Host "Target '$TargetDir' does not exist yet - creating it." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

Write-Host "Mirroring gentle-ai managed directories..." -ForegroundColor Cyan
foreach ($dir in $MirrorDirs) { Copy-MirrorDir -Name $dir }

Write-Host "Copying mcp/ configs (rewriting absolute binary paths for this machine)..." -ForegroundColor Cyan
Copy-McpConfigs

if ($PSCmdlet.ShouldProcess((Join-Path $TargetDir 'CLAUDE.md'), "Copy CLAUDE.md")) {
    Copy-Item -Path (Join-Path $SourceDir 'CLAUDE.md') -Destination (Join-Path $TargetDir 'CLAUDE.md') -Force
}
Write-Host "  = copied CLAUDE.md" -ForegroundColor DarkGray

Write-Host "Merging skills/ (new skills added, conflicts reported)..." -ForegroundColor Cyan
Merge-SkillsDir

Write-Host "Merging settings.json (existing target keys are never overwritten)..." -ForegroundColor Cyan
Merge-SettingsJson

Write-Host "`nDone. Restart Claude Code for the '$TargetDir' profile to pick up the changes." -ForegroundColor Cyan
Write-Host "Reminder: gentle-ai always installs/updates $HOME\.claude only - re-run this script after every 'gentle-ai upgrade' or 'gentle-ai sync' to keep '$TargetDir' in sync." -ForegroundColor Yellow
