#!/usr/bin/env bash
# hdv-release-project.sh
# Automates project validation, version bump, tag creation, and github release.

set -euo pipefail

echo "=== hdv-release-project ==="

# -------------------------------------------------------------
# ARGUMENTS PARSING
# -------------------------------------------------------------
RELEASE_TYPE=""
LOCAL_ONLY=false
SKIP_TEST=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        patch|minor|major)
            RELEASE_TYPE="$1"
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "Error: Unknown argument '$1'."
            echo "Usage: $0 {patch|minor|major} [--local-only] [--skip-test] [--skip-build]"
            exit 1
            ;;
    esac
done

if [[ -z "$RELEASE_TYPE" ]]; then
    echo "Error: Release type (patch/minor/major) is mandatory."
    echo "Usage: $0 {patch|minor|major} [--local-only] [--skip-test] [--skip-build]"
    exit 1
fi

# -------------------------------------------------------------
# 1. PRE-FLIGHT CHECKS
# -------------------------------------------------------------
echo ""
echo "[1/5] Running pre-flight checks..."

# Check if git is clean
GIT_STATUS=$(git status --porcelain)
if [[ -n "$GIT_STATUS" ]]; then
    echo "Error: Working directory has uncommitted changes. Please commit or stash them first."
    exit 1
fi

# Check if package.json exists
if [[ ! -f "package.json" ]]; then
    echo "Error: Unsupported project type. No package.json found."
    exit 1
fi

echo "  Pre-flight checks passed."

# -------------------------------------------------------------
# 2. QUALITY GATE
# -------------------------------------------------------------
echo ""
echo "[2/5] Running Quality Gates..."

# Check if jq is installed for parsing package.json
HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
fi

# Check and run test script
if [[ "$SKIP_TEST" == false ]]; then
    HAS_TEST=false
    if [[ "$HAS_JQ" == true ]]; then
        TEST_SCRIPT=$(jq -r '.scripts.test // empty' package.json)
        [[ -n "$TEST_SCRIPT" && "$TEST_SCRIPT" != *"no test specified"* ]] && HAS_TEST=true
    else
        grep -q '"test"' package.json && HAS_TEST=true
    fi

    if [[ "$HAS_TEST" == true ]]; then
        echo "  Running test script (npm test)..."
        npm test || { echo "Error: npm test failed. Aborting release."; exit 1; }
    else
        echo "  Skipping tests (no script defined or --skip-test active)."
    fi
else
    echo "  Skipping tests (--skip-test active)."
fi

# Check and run build script
if [[ "$SKIP_BUILD" == false ]]; then
    HAS_BUILD=false
    if [[ "$HAS_JQ" == true ]]; then
        BUILD_SCRIPT=$(jq -r '.scripts.build // empty' package.json)
        [[ -n "$BUILD_SCRIPT" ]] && HAS_BUILD=true
    else
        grep -q '"build"' package.json && HAS_BUILD=true
    fi

    if [[ "$HAS_BUILD" == true ]]; then
        echo "  Running build script (npm run build)..."
        npm run build || { echo "Error: npm run build failed. Aborting release."; exit 1; }
    else
        echo "  Skipping build (no script defined or --skip-build active)."
    fi
else
    echo "  Skipping build (--skip-build active)."
fi

echo "  Quality gates passed successfully."

# -------------------------------------------------------------
# 3. VERSION BUMP
# -------------------------------------------------------------
echo ""
echo "[3/5] Bumping version and generating changelog..."
npx standard-version --release-as "$RELEASE_TYPE" || { echo "Error: npx standard-version failed. Aborting release."; exit 1; }

# Read new version tag
if [[ "$HAS_JQ" == true ]]; then
    VERSION=$(jq -r '.version' package.json)
else
    VERSION=$(grep '"version"' package.json | head -n 1 | cut -d'"' -f4)
fi
VERSION_TAG="v$VERSION"
echo "  Local version bumped to $VERSION_TAG"

# -------------------------------------------------------------
# 4. GIT PUSH
# -------------------------------------------------------------
if [[ "$LOCAL_ONLY" == true ]]; then
    echo ""
    echo "[SWITCH] LocalOnly is active. Skipping remote push and GitHub release."
    echo "Done. Release $VERSION_TAG completed locally."
    exit 0
fi

echo ""
echo "[4/5] Pushing tags and commits to remote..."
ACTIVE_BRANCH=$(git branch --show-current)
git push origin "$ACTIVE_BRANCH" --follow-tags || { echo "Error: git push failed. Aborting release."; exit 1; }
echo "  Pushed to origin/$ACTIVE_BRANCH successfully."

# -------------------------------------------------------------
# 5. GITHUB RELEASE
# -------------------------------------------------------------
echo ""
echo "[5/5] Creating GitHub release..."
gh release create "$VERSION_TAG" --title "Release $VERSION_TAG" --generate-notes || { echo "Error: gh release create failed."; exit 1; }

echo ""
echo "Done. Release $VERSION_TAG published successfully!"
echo "========================================"
