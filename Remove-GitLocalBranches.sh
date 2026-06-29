#!/usr/bin/env bash
# Remove-GitLocalBranches.sh
# Deletes local branches whose remote counterpart no longer exists.
# Requires: fzf (apt install fzf)

set -euo pipefail

# 1. Limpiar referencias remotas inactivas
git fetch --prune > /dev/null 2>&1

# 2. Leer ramas protegidas desde .git-tools.json
REPO_ROOT=$(git rev-parse --show-toplevel)
CONFIG="$REPO_ROOT/.git-tools.json"

if command -v jq &> /dev/null && [ -f "$CONFIG" ]; then
    mapfile -t PROTECTED < <(jq -r '.protectedBranches[]' "$CONFIG")
else
    PROTECTED=("main" "develop")
fi

# 3. Rama actual
CURRENT=$(git rev-parse --abbrev-ref HEAD)

# 4. Filtrar ramas sin remote (gone)
CANDIDATES=()
while IFS= read -r line; do
    branch=$(echo "$line" | sed 's/^[* ]*//' | awk '{print $1}')
    skip=false
    for p in "${PROTECTED[@]}"; do
        [[ "$branch" == "$p" ]] && skip=true && break
    done
    [[ "$branch" == "$CURRENT" ]] && skip=true
    $skip || CANDIDATES+=("$branch")
done < <(git branch -vv | grep ': gone\]')

if [ ${#CANDIDATES[@]} -eq 0 ]; then
    echo "Nothing to clean up — all local branches have a remote counterpart."
    exit 0
fi

if ! command -v fzf &> /dev/null; then
    echo "fzf no encontrado. Instalalo con: sudo apt install fzf"
    exit 1
fi

# 5. Selección interactiva con fzf — todas pre-seleccionadas
SELECTED=$(printf '%s\n' "${CANDIDATES[@]}" | fzf \
    --multi \
    --bind 'start:select-all' \
    --prompt "Ramas a eliminar (TAB para toggle, ENTER para confirmar): " \
    --header "Rama actual: $CURRENT | Protegidas: ${PROTECTED[*]}")

if [ -z "$SELECTED" ]; then
    echo "Nada seleccionado."
    exit 0
fi

echo ""
echo "Eliminando:"
while IFS= read -r branch; do
    echo "  - $branch"
    git branch -D "$branch"
done <<< "$SELECTED"

echo ""
echo "Done."
