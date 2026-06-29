#!/usr/bin/env bash
# setup.sh
# Creates or updates .git-tools.json in the current repo root.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$REPO_ROOT" ]; then
    echo "Error: not inside a git repository."
    exit 1
fi

CONFIG="$REPO_ROOT/.git-tools.json"

if [ -f "$CONFIG" ]; then
    echo "Existing .git-tools.json found:"
    cat "$CONFIG"
    echo ""
    read -rp "Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

read -rp "Protected branches (comma-separated, default: main,develop): " input

if [ -z "$input" ]; then
    branches_json='"main", "develop"'
else
    branches_json=$(echo "$input" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s . | tr -d '\n' | sed 's/^\[//;s/\]$//')
fi

cat > "$CONFIG" <<EOF
{
    "protectedBranches": [$branches_json]
}
EOF

echo ""
echo "Created $CONFIG"
echo "Protected branches: $input"
