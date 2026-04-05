#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# --- Prerequisites ---
for cmd in openclaw npm pnpm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd command not found" >&2
    exit 1
  fi
done

OPENCLAW_BIN="$(which -a openclaw | tail -n 1)"
PLUGIN_ID="$(node -p "require('./openclaw.plugin.json').id")"

echo "═══ Step 1/3: Build & Install ═══════════════════════════"

echo "Building..."
pnpm build

PACKAGE_FILE="$(
  npm pack --json | node -e '
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => { data += chunk; });
    process.stdin.on("end", () => {
      const parsed = JSON.parse(data);
      const filename = parsed?.[0]?.filename;
      if (!filename) process.exit(1);
      process.stdout.write(filename);
    });
  '
)"

if [[ -z "$PACKAGE_FILE" || ! -f "$PACKAGE_FILE" ]]; then
  echo "failed to create package archive" >&2
  exit 1
fi

if "$OPENCLAW_BIN" plugins inspect "$PLUGIN_ID" >/dev/null 2>&1; then
  "$OPENCLAW_BIN" plugins uninstall "$PLUGIN_ID" --force
fi

echo "Installing plugin (dangerously-force-unsafe-install)..."
"$OPENCLAW_BIN" plugins install "$PACKAGE_FILE" --dangerously-force-unsafe-install
"$OPENCLAW_BIN" plugins enable "$PLUGIN_ID" >/dev/null 2>&1 || true

echo "Installed: $PACKAGE_FILE"

echo ""
echo "═══ Step 2/3: Restore Feishu Config ════════════════════"
bash "$(dirname "${BASH_SOURCE[0]}")/restore-feishu-config.sh"

echo ""
echo "═══ Step 3/3: Verify ═══════════════════════════════════"
INSTALLED_VER=$(node -p "require('$HOME/.openclaw/extensions/openclaw-lark/package.json').version")
echo "Installed version: $INSTALLED_VER"
echo ""
echo "✅ Done! Run 'openclaw gateway restart' to load the new plugin."
