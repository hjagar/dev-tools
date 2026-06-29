# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal Git workflow automation scripts. No build system, no tests, no package manager — pure shell scripts.

## Architecture

Every tool ships as a **pair**: a `.ps1` for Windows (PowerShell 5+) and a `.sh` for Linux/Mac (Bash). Both files must stay functionally equivalent when you add or change behavior.

| Pair | Purpose |
|------|---------|
| `Remove-GitLocalBranches.ps1 / .sh` | Deletes local branches whose remote is gone; reads protected branches from `.git-tools.json` |
| `setup.ps1 / .sh` | Interactively creates `.git-tools.json` in the current repo |
| `install.ps1 / .sh` | Downloads all scripts from GitHub raw to `~/.hjagar/dev-tools/` and adds them to PATH |

## Per-repo config

Scripts look for `.git-tools.json` at the repo root (via `git rev-parse --show-toplevel`). If absent, they fall back to `["main", "develop"]` as protected branches. The `.ps1` scripts parse JSON with `ConvertFrom-Json`; the `.sh` scripts use `jq` when available, same fallback otherwise.

## Platform differences

- **Windows** (`Remove-GitLocalBranches.ps1`): uses `System.Windows.Forms.CheckedListBox` for GUI branch selection.
- **Linux/Mac** (`Remove-GitLocalBranches.sh`): uses `fzf --multi --bind 'start:select-all'` for TUI selection. Requires `fzf`; `jq` is optional.

## Install scripts

`install.ps1` and `install.sh` fetch scripts directly from `https://raw.githubusercontent.com/hjagar/dev-tools/main/`. Changes must be **pushed to `main`** before the installers pick them up — the installers do not reference local files.

Install target: `~/.hjagar/dev-tools/` (both platforms). PATH is wired permanently via registry (Windows) and `.bashrc`/`.zshrc` (Linux/Mac).
