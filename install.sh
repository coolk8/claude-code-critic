#!/bin/bash
set -euo pipefail

# Install claude-code-critic globally into ~/.claude/settings.json
# The hook fires for all projects but only checks projects that have
# .claude/critic-rules/*.md files. No rules = no check.

CRITIC_PATH="$(cd "$(dirname "$0")" && pwd)/critic.mjs"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$CRITIC_PATH" ]; then
  echo "Error: critic.mjs not found at $CRITIC_PATH"
  exit 1
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Error: $SETTINGS_FILE not found"
  exit 1
fi

# Check if Stop hook already exists
if grep -q '"Stop"' "$SETTINGS_FILE" 2>/dev/null; then
  echo "Stop hook already configured in $SETTINGS_FILE"
  echo "Add manually if needed:"
  echo ""
  echo '  "Stop": [{"hooks": [{"type": "command", "command": "node \"'"$CRITIC_PATH"'\"", "timeout": 120}]}]'
  exit 0
fi

# Add Stop hook to existing global settings
node -e "
  const fs = require('fs');
  const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf-8'));
  settings.hooks = settings.hooks || {};
  settings.hooks.Stop = [{
    hooks: [{
      type: 'command',
      command: 'node \"$CRITIC_PATH\"',
      timeout: 120
    }]
  }];
  fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2) + '\n');
"

echo "Critic installed globally in $SETTINGS_FILE"
echo ""
echo "To enable for a project, add rules:"
echo "  mkdir -p /path/to/project/.claude/critic-rules"
echo "  cp $(dirname "$CRITIC_PATH")/example-rules/*.md /path/to/project/.claude/critic-rules/"
echo ""
echo "Model: \${CRITIC_MODEL:-opus} (override with CRITIC_MODEL env var)"
