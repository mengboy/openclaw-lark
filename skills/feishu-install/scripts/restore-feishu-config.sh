#!/usr/bin/env bash

set -euo pipefail

OPENCLAW_DIR="$HOME/.openclaw"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: openclaw.json not found at $CONFIG_FILE" >&2
  exit 1
fi

# Check if feishu config already exists
HAS_FEISHU=$(node -p "
  try {
    const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE', 'utf8'));
    c.channels?.feishu ? 'yes' : 'no';
  } catch(e) { 'error' }
" 2>/dev/null)

if [[ "$HAS_FEISHU" == "yes" ]]; then
  echo "✅ Feishu channel config already exists."
  node -e "
    const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE', 'utf8'));
    const f = c.channels.feishu;
    console.log('  appId:', f.appId);
    console.log('  domain:', f.domain);
    console.log('  streaming:', f.streaming);
    console.log('  groups:', Object.keys(f.groups || {}).length, 'group(s) configured');
  "
  exit 0
fi

echo "⚠️  Feishu channel config is missing. Searching for backup..."

# Find the most recent backup that contains feishu config
BAK_FILE=""
for candidate in \
  "$OPENCLAW_DIR/openclaw.json.bak" \
  "$OPENCLAW_DIR/openclaw.json.bak."* \
; do
  [[ -f "$candidate" ]] || continue
  HAS=$(node -p "
    try {
      const c = JSON.parse(require('fs').readFileSync('$candidate', 'utf8'));
      c.channels?.feishu ? 'yes' : 'no';
    } catch(e) { 'no' }
  " 2>/dev/null)
  if [[ "$HAS" == "yes" ]]; then
    BAK_FILE="$candidate"
  fi
done

if [[ -z "$BAK_FILE" ]]; then
  echo "ERROR: No backup with feishu config found." >&2
  echo "" >&2
  echo "Please manually restore from your own backup or re-enter the feishu" >&2
  echo "configuration (appId, appSecret, groups, etc.) into:" >&2
  echo "  $CONFIG_FILE" >&2
  exit 1
fi

echo "📦 Found feishu config in: $(basename "$BAK_FILE")"

# Extract and merge feishu config
node -e "
const fs = require('fs');
const configPath = '$CONFIG_FILE';
const bakPath = '$BAK_FILE';

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const bak = JSON.parse(fs.readFileSync(bakPath, 'utf8'));

if (!bak.channels?.feishu) {
  console.error('ERROR: backup does not contain channels.feishu');
  process.exit(1);
}

// Restore feishu channel config
config.channels.feishu = bak.channels.feishu;

// Write back with proper formatting
fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\\n');

// Print summary
const f = config.channels.feishu;
console.log('✅ Feishu channel config restored from', '$(basename "$BAK_FILE")');
console.log('');
console.log('  appId:', f.appId);
console.log('  domain:', f.domain);
console.log('  streaming:', f.streaming);
console.log('  groups:', Object.keys(f.groups || {}).length, 'group(s) configured');
console.log('');
console.log('Next steps:');
console.log('  1. openclaw gateway restart   (or start if not running)');
console.log('  2. Test by sending a message in Feishu');
"
