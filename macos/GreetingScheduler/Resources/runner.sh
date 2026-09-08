#!/bin/bash
set -uo pipefail
provider="$1"; executable="$2"; root="$3"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$root/logs" "$root/status"
# Kernel locks release automatically after a crash; keep the inode to avoid
# unlink/reacquire races. The lock holder waits for the complete greeting.
if [ "${4:-}" != '--locked' ]; then
  runID=$(/usr/bin/uuidgen)
  /usr/bin/lockf -k -s -t 0 "$root/status/$provider.lock" /bin/bash "$0" "$provider" "$executable" "$root" --locked "$runID"
  result=$?
  if [ "$result" -eq 75 ] && ! /usr/bin/grep -Fq "$runID" "$root/status/$provider.json" 2>/dev/null; then
    echo "GREETING_SCHEDULER_ALREADY_RUNNING"
    echo "[$(date)] Already running" >> "$root/logs/$provider.log"
  fi
  exit "$result"
fi
runID="$5"
started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
record() {
  printf '{"runID":"%s","pid":%s,"started":"%s","finished":"%s","exitCode":%s}\n' "$runID" "$$" "$started" "$1" "$2" > "$root/status/$provider.$$.tmp"
  mv -f "$root/status/$provider.$$.tmp" "$root/status/$provider.json"
}
finish() {
  result=$?
  trap - EXIT
  record "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$result"
  echo "[$(date)] Greeting finished (exit $result)" >> "$root/logs/$provider.log"
  exit "$result"
}
trap finish EXIT
# Wait for the child on termination so a replacement cannot overlap it.
child=''
trap 'if [ -n "$child" ]; then kill "$child" 2>/dev/null; wait "$child" 2>/dev/null; fi; exit 143' TERM INT
record '' null
exec >> "$root/logs/$provider.log" 2>&1
echo "[$(date)] Starting $provider greeting"
if [ ! -x "$executable" ]; then echo "Executable unavailable: $executable"; exit 127; fi
case "$provider" in
claude) "$executable" --print "Good morning" --no-session-persistence --tools "" --max-budget-usd 0.05 & ;;
codex) "$executable" exec --ephemeral --skip-git-repo-check --sandbox read-only "Good morning. Reply briefly with a greeting only. Do not use tools or inspect files." & ;;
*) exit 64 ;;
esac
child=$!
wait "$child"
exit $?
