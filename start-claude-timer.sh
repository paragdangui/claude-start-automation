#!/bin/bash

# launchd starts jobs with a minimal environment, so use the Claude binary
# installed for this account and derive project-relative paths from this file.
CLAUDE_BIN="/Users/parag/.local/bin/claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

mkdir -p "$LOG_DIR"

# Log start
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Claude timer..." >> "$LOG_DIR/stdout.log"

# Send the message through the current native Claude Code installation.
if "$CLAUDE_BIN" --print "Good morning" \
  --no-session-persistence \
  --tools "" \
  --max-budget-usd 0.05 >> "$LOG_DIR/stdout.log" 2>> "$LOG_DIR/stderr.log"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude timer started successfully" >> "$LOG_DIR/stdout.log"
else
  status=$?
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude timer failed (exit $status)" >> "$LOG_DIR/stderr.log"
  exit "$status"
fi
