#!/usr/bin/env bash
# install.sh
# Installs hjagar dev-tools scripts to ~/.hjagar/dev-tools and adds them to PATH.

set -euo pipefail

INSTALL_DIR="$HOME/.hjagar/dev-tools"
BASE_URL="https://raw.githubusercontent.com/hjagar/dev-tools/main"
SCRIPTS=(
    "Remove-GitLocalBranches.ps1"
    "Remove-GitLocalBranches.sh"
    "setup.ps1"
    "setup.sh"
    "uninstall.ps1"
    "uninstall.sh"
)

echo "Installing hjagar/dev-tools to $INSTALL_DIR ..."

mkdir -p "$INSTALL_DIR"

for script in "${SCRIPTS[@]}"; do
    echo "  Downloading $script ..."
    curl -fsSL "$BASE_URL/$script" -o "$INSTALL_DIR/$script"
done

chmod +x "$INSTALL_DIR/Remove-GitLocalBranches.sh" "$INSTALL_DIR/setup.sh" "$INSTALL_DIR/uninstall.sh"

PATH_LINE="export PATH=\"\$HOME/.hjagar/dev-tools:\$PATH\""
COMMENT="# hjagar dev-tools"
ADDED=false

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] && ! grep -q ".hjagar/dev-tools" "$rc"; then
        printf "\n%s\n%s\n" "$COMMENT" "$PATH_LINE" >> "$rc"
        echo "  Added PATH entry to $rc"
        ADDED=true
    fi
done

if [ "$ADDED" = false ]; then
    echo "  PATH entry already present or no .bashrc/.zshrc found."
fi

echo ""
echo "Done. Restart your terminal or run: source ~/.bashrc"
