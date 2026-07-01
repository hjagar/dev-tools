#!/usr/bin/env bash
# install.sh
# Installs hjagar dev-tools scripts to ~/.hjagar/dev-tools and adds them to PATH.

set -euo pipefail

command -v unzip &> /dev/null || {
    echo "Error: unzip is required to install dev-tools."
    echo "Please install it first (e.g. sudo apt install unzip / brew install unzip)."
    exit 1
}

INSTALL_DIR="$HOME/.hjagar/dev-tools"
ZIP_URL="https://github.com/hjagar/dev-tools/releases/latest/download/dev-tools.zip"
ZIP_PATH="$INSTALL_DIR/dev-tools.zip"

echo "Installing hjagar/dev-tools to $INSTALL_DIR ..."

mkdir -p "$INSTALL_DIR"

# Ensure the zip file is always cleaned up on exit
trap 'rm -f "$ZIP_PATH"' EXIT

echo "  Downloading latest release package..."
curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"

echo "  Extracting files..."
unzip -o "$ZIP_PATH" -d "$INSTALL_DIR"

chmod +x "$INSTALL_DIR"/*.sh

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
