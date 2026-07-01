#!/usr/bin/env bash
set -euo pipefail

echo "=== Release-Repo ==="

command -v shellcheck &> /dev/null || { echo "Error: shellcheck not found. Install: sudo apt install shellcheck / brew install shellcheck"; exit 1; }
command -v zip        &> /dev/null || { echo "Error: zip not found. Install: sudo apt install zip / brew install zip"; exit 1; }
command -v gh         &> /dev/null || { echo "Error: gh not found. Install: https://cli.github.com"; exit 1; }

RELEASE_TYPE="${1:-}"
if [[ -z "$RELEASE_TYPE" ]]; then
    read -rp "Release type (patch/minor/major): " RELEASE_TYPE
fi
if [[ ! "$RELEASE_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "Error: release type must be patch, minor, or major."
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "[1/5] Quality gate (shellcheck)..."
GATE_FAILED=false
for f in *.sh; do
    echo "  checking $f..."
    if ! shellcheck "$f"; then
        GATE_FAILED=true
    fi
done
if [[ "$GATE_FAILED" == true ]]; then
    echo "shellcheck failed. Aborting — nothing was created."
    exit 1
fi
echo "  All shell scripts passed."

echo "[2/5] Version bump..."
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [[ -z "$LAST_TAG" ]]; then
    NEXT_VERSION="v1.0.0"
    echo "  No existing tags. Proposing first release $NEXT_VERSION."
else
    VER="${LAST_TAG#v}"
    MAJOR=$(echo "$VER" | cut -d. -f1)
    MINOR=$(echo "$VER" | cut -d. -f2)
    PATCH=$(echo "$VER" | cut -d. -f3)
    case "$RELEASE_TYPE" in
        major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR+1)); PATCH=0 ;;
        patch) PATCH=$((PATCH+1)) ;;
    esac
    NEXT_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
    echo "  $LAST_TAG -> $NEXT_VERSION ($RELEASE_TYPE)"
fi
read -rp "Create release $NEXT_VERSION? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled. Nothing was created."
    exit 0
fi

echo "[3/5] Packaging..."
BUILD_DIR="$REPO_ROOT/build"
ZIP_PATH="$BUILD_DIR/dev-tools.zip"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mapfile -t FILES < <(find . -maxdepth 1 -type f ! -name 'Release-Repo.*' -printf '%f\n')
zip -j "$ZIP_PATH" "${FILES[@]}"
echo "  Created build/dev-tools.zip"

echo "[4/5] Tag + push..."
git tag -a "$NEXT_VERSION" -m "Release $NEXT_VERSION"
git push --follow-tags
echo "  Tagged and pushed $NEXT_VERSION."

echo "[5/5] Publishing GitHub release..."
if ! gh release create "$NEXT_VERSION" "$ZIP_PATH" --generate-notes; then
    echo "gh release create failed (check 'gh auth status'). Tag $NEXT_VERSION is already pushed — re-run after auth to reuse it."
    exit 1
fi
rm -rf "$BUILD_DIR"

echo ""
echo "Done. Release $NEXT_VERSION published."
