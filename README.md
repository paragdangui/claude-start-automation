# Auto Session Start

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

## Native macOS app

The SwiftUI app in `macos/` provides independent weekday schedules, an explicit
Apply button, Run now, persistent run status, logs, and executable path Settings.
Opening the app does not install jobs or send greetings. Run now sends a request
through the selected service, even when its schedule is disabled.

A local Release copy is installed at `~/Applications/Auto Session Start.app`.
Open it in Finder or drag it to the Dock. It uses a regular application window,
not a menu bar icon. Closing the window or using Command-Q leaves enabled
LaunchAgents running. Clicking the app again reopens its main window.

### Build and install

Requires macOS 13 or newer and a compatible Swift/macOS SDK. Open
`macos/GreetingScheduler.xcodeproj` in full Xcode and build the AutoSessionStart
target, or use the tested Command Line Tools build:

```bash
./macos/build.sh
mkdir -p "$HOME/Applications"
ditto "macos/build/Auto Session Start.app" "$HOME/Applications/Auto Session Start.app"
open "$HOME/Applications/Auto Session Start.app"
```

Quit the app before replacing an existing copy. The build is ad-hoc signed for
local personal use and has no App Sandbox. No paid Apple Developer membership,
server, hosting, or App Store submission is needed. Provider subscriptions/API
usage and internet access still apply; this app does not store credentials or
perform login flows. CLI output is retained locally in logs.

### Setup, settings, and migration

On a fresh installation, review executable paths in Settings, then choose
**Install schedules**. Existing installed weekday times take precedence over
repository defaults. Unsupported schedules require an explicit **Replace existing
schedule** selection. Each provider reports its own update errors; one missing
CLI does not prevent configuring the other provider. Disabling remains possible
if an executable has been removed.

Time, enabled state, and executable path edits are drafts until **Apply schedule**
is pressed for that provider. The installed schedule is shown separately.
Run now uses the currently selected executable path. Successful greetings do not
verify any quota or usage-window reset. Failures show an exit code and View logs;
repair login externally when needed.

The app reuses `com.user.claude.timer` and `com.user.codex.timer`, backs up old
plists, and installs standalone runners. It does not trigger a greeting when
loading a schedule. After migration, manage schedules in the app; do not run the
old `install.sh`, which would replace the app’s configuration. The legacy CLI
workflow remains available for users who have not migrated.

App files live in `~/Library/Application Support/GreetingScheduler/`:

- `settings.json`: versioned settings, saved atomically.
- `runners/`: installed scripts independent of the app/source checkout.
- `logs/`: provider output and launchd logs.
- `status/`: atomic JSON run records and kernel lock files.
- `backups/`: previous LaunchAgent plists.

Legacy scripts in `~/bin/` and historical logs in `~/bin/logs/` are preserved.
The app needs no repository checkout at runtime and derives paths from the
current user’s home. Enabled schedules require a powered-on Mac and available
user session; the app does not wake the Mac or promise exact execution during sleep.

### Remove the app

Disable both schedules and press Apply for each **before** deleting the app.
Moving or deleting the app alone does not remove its jobs. You may then delete
`~/Applications/Auto Session Start.app`. Settings and logs remain in Application
Support until you choose to remove them. The earlier launchctl uninstall commands
also remove the jobs if the app is unavailable.

### Verification

Run `./macos/test.sh` for isolated stub and core tests. The optional
`python3 macos/tests/test_launchd.py` loads a temporary uniquely named launchd job
and waits up to 90 seconds for a local stub run, then cleans up.
See [macos/VERIFICATION.md](macos/VERIFICATION.md) for results and remaining manual
checks. No real service requests are required by these tests.

The app uses a clock-and-play icon for scheduled session starts. Its bundle identifier and Application Support folder retain `GreetingScheduler` for compatibility with existing settings and jobs. To regenerate the icon, run `bash macos/tools/generate-icon.sh`.
