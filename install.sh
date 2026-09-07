#!/bin/bash
set -euo pipefail

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--preview" ) ]]; then
  echo "Usage: bash install.sh [--preview]" >&2
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/schedule.env"

# Validate both schedules before changing either installed job.
for variable in CLAUDE_RUN_TIME CODEX_RUN_TIME; do
  value="${!variable:-}"
  if [[ ! "$value" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Set $variable in schedule.env to a valid 24-hour time (HH:MM)." >&2
    exit 1
  fi
done

generated_dir="$(mktemp -d)"
trap 'rm -rf "$generated_dir"' EXIT
for provider in claude codex; do
  if [[ "$provider" == claude ]]; then
    run_time="$CLAUDE_RUN_TIME"
  else
    run_time="$CODEX_RUN_TIME"
  fi
  # Convert to decimal so leading zeroes are not treated as octal.
  run_hour=$((10#${run_time%:*}))
  run_minute=$((10#${run_time#*:}))
  generated_plist="$generated_dir/com.user.$provider.timer.plist"
  sed -e "s/__RUN_HOUR__/$run_hour/g" \
      -e "s/__RUN_MINUTE__/$run_minute/g" \
      "$SCRIPT_DIR/com.user.$provider.timer.plist" > "$generated_plist"
  plutil -lint "$generated_plist" >/dev/null
done

# Preview both generated configurations without installing or reloading them.
if [[ "${1:-}" == "--preview" ]]; then
  for provider in claude codex; do
    echo "<!-- com.user.$provider.timer.plist -->"
    cat "$generated_dir/com.user.$provider.timer.plist"
  done
  exit 0
fi

domain="gui/$(id -u)"
mkdir -p "$HOME/bin/logs" "$HOME/Library/LaunchAgents"
for provider in claude codex; do
  label="com.user.$provider.timer"
  agent_path="$HOME/Library/LaunchAgents/$label.plist"
  cp "$SCRIPT_DIR/start-$provider-timer.sh" "$HOME/bin/start-$provider-timer.sh"
  cp "$generated_dir/$label.plist" "$agent_path"
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    launchctl bootout "$domain/$label"
  fi
  launchctl bootstrap "$domain" "$agent_path"
done
echo "Installed weekday schedules: Claude at $CLAUDE_RUN_TIME, Codex at $CODEX_RUN_TIME (local system time)."
