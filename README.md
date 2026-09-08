# Claude and Codex Morning Automation

Sends a short greeting through each CLI every Monday–Friday using macOS launchd:

- Claude: **8:30 AM**
- Codex: **8:00 AM**

Times use the Mac's local timezone. These greetings are intended to start morning
usage; successful execution does not verify a usage-window reset.

## Configuration and installation

Edit `schedule.env` to change the independent schedules:

```bash
CLAUDE_RUN_TIME=08:30
CODEX_RUN_TIME=08:00
```

Use 24-hour `HH:MM` format, then apply both schedules:

```bash
bash install.sh --preview
bash install.sh
```

The installer validates both times and generates and lints both plists before
installing either job. Preview prints both configurations without installing them.
The plist files are templates; do not copy them directly into LaunchAgents.
Installation reloads both jobs but does not immediately send greetings.

This checkout is configured for the local account `parag`, Claude at
`~/.local/bin/claude`, and Codex at
`/Applications/ChatGPT.app/Contents/Resources/codex`. Codex uses the existing
ChatGPT CLI login. Check it with `codex login status`; use `codex login` if needed.
For Claude authentication issues, use `claude setup-token`.

## Project files

- `start-claude-timer.sh` and `start-codex-timer.sh`: greeting scripts.
- `com.user.claude.timer.plist` and `com.user.codex.timer.plist`: weekday templates.
- `schedule.env`: independent start times.
- `install.sh`: preview, install, and reload both schedules.

Installed scripts live in `~/bin/`, with jobs in `~/Library/LaunchAgents/`.
Claude keeps its existing invocation. Codex runs non-interactively with an
ephemeral session, a read-only sandbox, and a prompt requesting a brief greeting
without tools or file inspection. Both scripts record success or failure;
Codex also records its exit status.

No terminal or application window needs to stay open. The Mac must be powered
on and the user session available. A scheduled job missed during sleep can run
when the Mac wakes; this does not wake a powered-off Mac.

## Status and manual runs

Inspect the loaded jobs and schedules:

```bash
launchctl print gui/$(id -u)/com.user.claude.timer
launchctl print gui/$(id -u)/com.user.codex.timer
```

Optionally send a greeting immediately (this uses the respective service):

```bash
launchctl kickstart gui/$(id -u)/com.user.claude.timer
launchctl kickstart gui/$(id -u)/com.user.codex.timer
```

## Logs

Installed runs write to `~/bin/logs/`; running a source script directly writes
to this checkout's `logs/` directory.

| Job | Greeting output | Greeting errors | launchd output / errors |
| --- | --- | --- | --- |
| Claude | `stdout.log` | `stderr.log` | `launchd-stdout.log` / `launchd-stderr.log` |
| Codex | `codex-stdout.log` | `codex-stderr.log` | `codex-launchd-stdout.log` / `codex-launchd-stderr.log` |

```bash
tail -20 ~/bin/logs/stdout.log ~/bin/logs/stderr.log
tail -20 ~/bin/logs/codex-stdout.log ~/bin/logs/codex-stderr.log
```

## Uninstall

Remove either job independently by setting `provider` to `claude` or `codex`:

```bash
provider=codex
launchctl bootout gui/$(id -u)/com.user.$provider.timer
rm ~/Library/LaunchAgents/com.user.$provider.timer.plist
rm ~/bin/start-$provider-timer.sh
```

Logs are retained.
