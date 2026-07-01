#!/usr/bin/env bash
set -euo pipefail

read -r -p "Remove hjagar/dev-tools? This will delete files and edit your shell config. (y/N) " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

INSTALL_DIR="$HOME/.hjagar/dev-tools"
PARENT_DIR="$HOME/.hjagar"
COMMENT='# hjagar dev-tools'
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.hjagar/dev-tools:$PATH"'

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || { echo "  $rc not found (skip)"; continue; }
    tmp="$(mktemp)"
    awk -v c="$COMMENT" -v p="$PATH_LINE" '$0 != c && $0 != p { print }' "$rc" > "$tmp"
    if cmp -s "$rc" "$tmp"; then
        echo "  no block in $rc (skip)"
        rm -f "$tmp"
    else
        cat "$tmp" > "$rc"
        rm -f "$tmp"
        echo "  removed block from $rc"
    fi
done

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
else
    echo "Install dir not found (skip)"
fi

if [ -d "$PARENT_DIR" ] && [ -z "$(ls -A "$PARENT_DIR")" ]; then
    rmdir "$PARENT_DIR"
    echo "Removed $PARENT_DIR"
else
    echo "$PARENT_DIR not empty or not found (kept)"
fi

SELF="${BASH_SOURCE[0]}"
case "$SELF" in
    "$INSTALL_DIR"/*) [ -e "$SELF" ] && rm -f -- "$SELF" ;;
    *) echo "Running from clone — remove uninstall.sh manually if needed." ;;
esac

echo "Done. Restart your terminal to reload PATH."
