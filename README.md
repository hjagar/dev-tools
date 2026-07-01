# hjagar/dev-tools

Personal dev tools for Git workflow automation. Works on Windows (PowerShell) and Linux/Mac (Bash).

---

## Scripts

| Script | Description |
|--------|-------------|
| `Remove-GitLocalBranches.ps1` | Deletes local branches whose remote was deleted (Windows) |
| `Remove-GitLocalBranches.sh` | Same, for Linux/Mac |
| `dev-tools-setup.ps1` | Creates `.git-tools.json` in the current repo (Windows) |
| `dev-tools-setup.sh` | Same, for Linux/Mac |

---

## Requirements

**Windows**
- PowerShell 5+ (included in Windows 10/11)

**Linux / Mac**
- [`fzf`](https://github.com/junegunn/fzf) — interactive selection (`sudo apt install fzf` / `brew install fzf`)
- `jq` — JSON parsing, optional (falls back to default branches if missing) (`sudo apt install jq` / `brew install jq`)
- `unzip` — extraction tool (`sudo apt install unzip` / `brew install unzip`)

**Prerequisites for releasing (maintainer)**
- [`gh`](https://cli.github.com) — GitHub CLI (`winget install GitHub.cli` / `sudo apt install gh` / `brew install gh`)
- [`shellcheck`](https://www.shellcheck.net) — shell script linter (`winget install koalaman.shellcheck` / `sudo apt install shellcheck` / `brew install shellcheck`)
- `zip` — archive tool, Linux/Mac only (`sudo apt install zip` / `brew install zip`)

---

## Installation

### Option A — Clone the repo (recommended if you plan to contribute or modify scripts)

```powershell
# Windows
git clone https://github.com/hjagar/dev-tools.git C:\Work\Hjagarsoft\dev-tools
```
```bash
# Linux / Mac
git clone https://github.com/hjagar/dev-tools.git ~/hjagar-dev-tools
```

Then add the folder to your PATH manually:

**Windows** — add to your PowerShell profile (`$PROFILE`):
```powershell
$env:PATH += ";C:\Work\Hjagarsoft\dev-tools"
```

**Linux / Mac** — add to `~/.bashrc` or `~/.zshrc`:
```bash
export PATH="$HOME/hjagar-dev-tools:$PATH"
```

---

### Option B — Automatic installer (no cloning needed)

**Windows** (PowerShell as Administrator):
```powershell
irm https://raw.githubusercontent.com/hjagar/dev-tools/main/install.ps1 | iex
```

**Linux / Mac**:
```bash
curl -fsSL https://raw.githubusercontent.com/hjagar/dev-tools/main/install.sh | bash
```

Scripts are installed to `~/.hjagar/dev-tools/`. PATH is configured automatically in your shell profile.

---

## Per-repo setup

Each repo needs a `.git-tools.json` file at its root to declare which branches are protected (never deleted). Run the setup script from inside the repo:

```powershell
# Windows
dev-tools-setup.ps1
```
```bash
# Linux / Mac
dev-tools-setup.sh
```

Or create it manually:

```json
{
    "protectedBranches": ["main", "develop"]
}
```

Commit this file — it's shared configuration for the whole team.

---

## Usage

Run from any directory inside a git repo:

```powershell
# Windows — opens a GUI checklist with all purgeable branches pre-selected
Remove-GitLocalBranches.ps1
```

```bash
# Linux / Mac — opens fzf with all purgeable branches pre-selected (TAB to toggle)
Remove-GitLocalBranches.sh
```

Branches listed in `.git-tools.json` and the current branch are always excluded.

---

## Releasing a new version

> Maintainer-only. Requires `gh`, `shellcheck`, and `zip` (Linux/Mac) in PATH.

Run from inside the repo (any branch):

```powershell
# Windows
.\Release-Repo.ps1 -ReleaseType patch   # or minor / major
```
```bash
# Linux / Mac
./Release-Repo.sh patch   # or minor / major
```

The script runs 5 steps in order — any failure aborts the rest:

1. **Quality gate** — `shellcheck` checks every `.sh` file. Fails fast if any error found.
2. **Version bump** — computes next semver from the latest tag (proposes `v1.0.0` if no tags exist). Asks for confirmation before proceeding.
3. **Package** — creates `build/dev-tools.zip` with all distributable scripts (excludes `Release-Repo.*`).
4. **Tag + push** — creates annotated tag `vX.Y.Z` and pushes with `--follow-tags`.
5. **Publish + cleanup** — creates GitHub release with the zip attached and auto-generated notes; removes `build/`.

---

## `.git-tools.json` reference

```json
{
    "protectedBranches": ["main", "develop", "staging"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `protectedBranches` | `string[]` | Branches that will never be shown for deletion |

---

---

# hjagar/dev-tools (Español)

Herramientas personales para automatizar el workflow con Git. Funciona en Windows (PowerShell) y Linux/Mac (Bash).

---

## Scripts

| Script | Descripción |
|--------|-------------|
| `Remove-GitLocalBranches.ps1` | Elimina ramas locales cuyo remote fue borrado (Windows) |
| `Remove-GitLocalBranches.sh` | Lo mismo, para Linux/Mac |
| `dev-tools-setup.ps1` | Crea `.git-tools.json` en el repo actual (Windows) |
| `dev-tools-setup.sh` | Lo mismo, para Linux/Mac |

---

## Requisitos

**Windows**
- PowerShell 5+ (incluido en Windows 10/11)

**Linux / Mac**
- [`fzf`](https://github.com/junegunn/fzf) — selección interactiva (`sudo apt install fzf` / `brew install fzf`)
- `jq` — parseo de JSON, opcional (usa valores por defecto si no está) (`sudo apt install jq` / `brew install jq`)
- `unzip` — herramienta de extracción (`sudo apt install unzip` / `brew install unzip`)

**Requisitos para release (maintainer)**
- [`gh`](https://cli.github.com) — GitHub CLI (`winget install GitHub.cli` / `sudo apt install gh` / `brew install gh`)
- [`shellcheck`](https://www.shellcheck.net) — linter de shell scripts (`winget install koalaman.shellcheck` / `sudo apt install shellcheck` / `brew install shellcheck`)
- `zip` — herramienta de archivos, solo Linux/Mac (`sudo apt install zip` / `brew install zip`)

---

## Instalación

### Opción A — Clonar el repo (recomendado si querés modificar los scripts)

```powershell
# Windows
git clone https://github.com/hjagar/dev-tools.git C:\Work\Hjagarsoft\dev-tools
```
```bash
# Linux / Mac
git clone https://github.com/hjagar/dev-tools.git ~/hjagar-dev-tools
```

Luego agregás la carpeta al PATH manualmente:

**Windows** — en tu perfil de PowerShell (`$PROFILE`):
```powershell
$env:PATH += ";C:\Work\Hjagarsoft\dev-tools"
```

**Linux / Mac** — en `~/.bashrc` o `~/.zshrc`:
```bash
export PATH="$HOME/hjagar-dev-tools:$PATH"
```

---

### Opción B — Installer automático (sin clonar)

**Windows** (PowerShell):
```powershell
irm https://raw.githubusercontent.com/hjagar/dev-tools/main/install.ps1 | iex
```

**Linux / Mac**:
```bash
curl -fsSL https://raw.githubusercontent.com/hjagar/dev-tools/main/install.sh | bash
```

Los scripts se instalan en `~/.hjagar/dev-tools/`. El PATH se configura automáticamente en tu shell.

---

## Setup por repo

Cada repo necesita un archivo `.git-tools.json` en la raíz para declarar qué ramas están protegidas (nunca se borran). Corrés el script de setup desde dentro del repo:

```powershell
# Windows
dev-tools-setup.ps1
```
```bash
# Linux / Mac
dev-tools-setup.sh
```

O lo creás a mano:

```json
{
    "protectedBranches": ["main", "develop"]
}
```

Commiteá este archivo — es configuración compartida con el equipo.

---

## Uso

Desde cualquier directorio dentro de un repo git:

```powershell
# Windows — abre una lista con checkboxes, todas las ramas pre-seleccionadas
Remove-GitLocalBranches.ps1
```

```bash
# Linux / Mac — abre fzf con todas las ramas pre-seleccionadas (TAB para toggle)
Remove-GitLocalBranches.sh
```

Las ramas en `.git-tools.json` y la rama actual siempre quedan excluidas.

---

## Publicar una versión

> Solo para maintainers. Requiere `gh`, `shellcheck`, y `zip` (Linux/Mac) en el PATH.

Ejecutá desde dentro del repo (cualquier rama):

```powershell
# Windows
.\Release-Repo.ps1 -ReleaseType patch   # o minor / major
```
```bash
# Linux / Mac
./Release-Repo.sh patch   # o minor / major
```

El script ejecuta 5 pasos en orden — cualquier falla aborta el resto:

1. **Control de calidad** — `shellcheck` revisa todos los archivos `.sh`. Falla inmediatamente si encuentra errores.
2. **Bump de versión** — calcula el próximo semver a partir del último tag (propone `v1.0.0` si no hay tags). Pide confirmación antes de continuar.
3. **Empaquetado** — crea `build/dev-tools.zip` con todos los scripts distribuibles (excluye `Release-Repo.*`).
4. **Tag + push** — crea un tag anotado `vX.Y.Z` y lo sube con `--follow-tags`.
5. **Publicación + limpieza** — crea el release en GitHub con el zip adjunto y notas auto-generadas; elimina `build/`.
