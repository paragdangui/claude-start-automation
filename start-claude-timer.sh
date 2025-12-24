#!/bin/bash

# Define paths explicitly
NODE_BIN="/Users/paragsmartshore/.nvm/versions/node/v22.17.1/bin/node"
CLAUDE_DIR="/Users/paragsmartshore/.nvm/versions/node/v22.17.1/lib/node_modules/@anthropic-ai/claude-code"
LOG_DIR="/Users/paragsmartshore/Documents/websites/test-websites/claude-start-automation/logs"

# Log start
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Claude timer..." >> "$LOG_DIR/stdout.log"

# Change to Claude directory (required for relative imports)
cd "$CLAUDE_DIR"

# Send message via CLI (using node directly)
"$NODE_BIN" cli.js --print "Good morning" \
  --no-session-persistence \
  --tools "" \
  --max-budget-usd 0.05 >> "$LOG_DIR/stdout.log" 2>> "$LOG_DIR/stderr.log"

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude timer started successfully" >> "$LOG_DIR/stdout.log"
