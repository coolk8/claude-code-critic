#!/bin/bash
set -euo pipefail

# Install claude-code-critic into a project's .claude/settings.json
# Usage: ./install.sh [project-path]
#   project-path defaults to current directory

PROJECT_DIR="${1:-.}"
SETTINGS_FILE="${PROJECT_DIR}/.claude/settings.local.json"
CRITIC_PATH="$(cd "$(dirname "$0")" && pwd)/critic.mjs"

if [ ! -f "$CRITIC_PATH" ]; then
  echo "Error: critic.mjs not found at $CRITIC_PATH"
  exit 1
fi

# Ensure .claude directory exists
mkdir -p "${PROJECT_DIR}/.claude"

# Create or update settings file
if [ -f "$SETTINGS_FILE" ]; then
  # Check if Stop hook already exists
  if grep -q '"Stop"' "$SETTINGS_FILE" 2>/dev/null; then
    echo "Stop hook already configured in $SETTINGS_FILE"
    echo "Add manually if needed:"
    echo ""
    echo '  "Stop": [{"hooks": [{"type": "command", "command": "node \"'"$CRITIC_PATH"'\"", "timeout": 120}]}]'
    exit 0
  fi

  # Add Stop hook to existing settings using node
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
  echo "Added critic Stop hook to $SETTINGS_FILE"
else
  # Create new settings file with just the hook
  cat > "$SETTINGS_FILE" << SETTINGS
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CRITIC_PATH\"",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
SETTINGS
  echo "Created $SETTINGS_FILE with critic Stop hook"
fi

echo ""
echo "Critic installed. It will check every Claude response against rules in:"
echo "  $CRITIC_PATH/../rules/"
echo ""
echo "Model: \${CRITIC_MODEL:-opus} (override with CRITIC_MODEL env var)"
echo "To add rules: create .md files in the rules/ directory"
