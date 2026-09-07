#!/bin/bash
set -euo pipefail

# Use an absolute path because launchd has a minimal environment.
CODEX_BIN="/Applications/ChatGPT.app/Contents/Resources/codex"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Codex greeting..." >> "$LOG_DIR/codex-stdout.log"
if "$CODEX_BIN" exec --ephemeral --skip-git-repo-check --sandbox read-only \
  "Good morning. Reply briefly with a greeting only. Do not use tools or inspect files." \
  >> "$LOG_DIR/codex-stdout.log" 2>> "$LOG_DIR/codex-stderr.log"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex greeting completed successfully (exit 0)" >> "$LOG_DIR/codex-stdout.log"
else
  status=$?
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex greeting failed (exit $status)" >> "$LOG_DIR/codex-stderr.log"
  exit "$status"
fi
