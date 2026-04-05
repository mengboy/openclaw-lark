#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

MENGBOY_REMOTE="${MENGBOY_REMOTE:-mengboy}"
ORIGIN_REMOTE="${ORIGIN_REMOTE:-origin}"

echo "═══ Step 1/6: Fetch latest origin ═════════════════════════════"
git fetch "$ORIGIN_REMOTE"
git fetch "$MENGBOY_REMOTE"

echo ""
echo "═══ Step 2/6: Check current state ═════════════════════════════"
MENGBOY_MAIN="$MENGBOY_REMOTE/main"
ORIGIN_MAIN="$ORIGIN_REMOTE/main"

if ! git rev-parse --verify "$MENGBOY_MAIN" >/dev/null 2>&1; then
  echo "ERROR: Remote branch $MENGBOY_MAIN not found. Make sure $MENGBOY_REMOTE is configured." >&2
  exit 1
fi

if ! git rev-parse --verify "$ORIGIN_MAIN" >/dev/null 2>&1; then
  echo "ERROR: Remote branch $ORIGIN_MAIN not found. Make sure $ORIGIN_REMOTE is configured." >&2
  exit 1
fi

echo "Origin latest: $(git log --oneline -1 "$ORIGIN_MAIN")"
echo "Mengboy main:  $(git log --oneline -1 "$MENGBOY_MAIN")"

# Check if mengboy already has origin changes
if git merge-base --is-ancestor "$ORIGIN_MAIN" "$MENGBOY_MAIN" 2>/dev/null; then
  echo ""
  echo "✅ Mengboy main already includes latest origin changes. No upgrade needed."
  exit 0
fi

echo ""
echo "⚠️  Origin has new commits not yet in mengboy. Starting upgrade..."

echo ""
echo "═══ Step 3/6: Create upgrade branch ═══════════════════════════"
UPGRADE_BRANCH="upgrade-from-origin-$(date +%Y-%m-%d)"
git checkout -b "$UPGRADE_BRANCH" "$ORIGIN_MAIN"
echo "Created branch: $UPGRADE_BRANCH (from $ORIGIN_MAIN)"

echo ""
echo "═══ Step 4/6: Export mengboy streaming card changes as patch ═════"
# Export the diff between origin and mengboy for the card-related files
CARD_FILES=(
  "src/card/"
  "src/channel/plugin.ts"
  "src/core/config-schema.ts"
  "src/core/lark-client.ts"
  "src/core/token-store.ts"
  "src/core/tool-scopes.ts"
  "src/messaging/inbound/dispatch-commands.ts"
  "src/messaging/inbound/dispatch.ts"
  "src/tools/mcp/shared.ts"
  "src/tools/oapi/index.ts"
  "src/tools/oapi/task/index.ts"
  "tests/"
  "bin/openclaw-lark.js"
  "index.ts"
  "package.json"
  "pnpm-lock.yaml"
)

PATCH_FILE="/tmp/mengboy-card-patch-$(date +%s).diff"

# Build the diff from origin/main to mengboy/main for card-related files
git diff "$ORIGIN_MAIN".."$MENGBOY_MAIN" -- "${CARD_FILES[@]}" > "$PATCH_FILE"

PATCH_LINES=$(wc -l < "$PATCH_FILE")
if [[ "$PATCH_LINES" -lt 10 ]]; then
  echo "WARNING: Patch file is very small ($PATCH_LINES lines). This may indicate no card changes exist." >&2
  echo "Continuing anyway in case there are minor changes..."
fi

echo "Exported patch: $PATCH_FILE ($PATCH_LINES lines)"

echo ""
echo "═══ Step 5/6: Apply patch to origin-based branch ══════════════"
if git apply --check "$PATCH_FILE" 2>/dev/null; then
  git apply "$PATCH_FILE"
  echo "✅ Patch applied successfully."
else
  echo "⚠️  Patch has conflicts. Applying with --3way..."
  if git apply --3way "$PATCH_FILE" 2>/dev/null; then
    echo "✅ 3-way merge succeeded."
  else
    echo "ERROR: 3-way merge also failed. Manual resolution needed." >&2
    echo "  Files with conflicts:" >&2
    git diff --name-only --diff-filter=U 2>/dev/null || echo "  (check with git status)" >&2
    exit 1
  fi
fi

# Stage all changes (including deletions)
git add -A

# Commit the changes
git commit -m "feat: reapply streaming card improvements on latest origin

- Rebase mengboy streaming card changes onto $(git log --oneline -1 "$ORIGIN_MAIN")
- Runtime metadata (provider, model, agent label)
- Compaction start/end callbacks
- Improved streaming card status display
- Simplified tool use display
- Updated tests for new streaming behavior"

echo ""
echo "═══ Step 6/6: Rebuild and install ════════════════════════════"
bash "$(dirname "${BASH_SOURCE[0]}")/reinstall-feishu.sh"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Upgrade complete!"
echo ""
echo "Branch: $UPGRADE_BRANCH"
echo "Latest commit: $(git log --oneline -1)"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff origin/main..HEAD"
echo "  2. Test: openclaw gateway restart"
echo "  3. Push to mengboy: git push $MENGBOY_REMOTE $UPGRADE_BRANCH:main --force"
echo ""
echo "To push immediately:"
echo "  git push $MENGBOY_REMOTE $UPGRADE_BRANCH:main --force"
echo "═══════════════════════════════════════════════════════════════"
