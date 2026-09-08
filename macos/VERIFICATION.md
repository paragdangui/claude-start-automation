# Verification — 2026-09-08

Environment: macOS 26.6.2, Apple Silicon, Swift 6.3.3 and Command Line Tools SDK. Full Xcode is not installed/selected. The Xcode project passes property-list lint; an Xcode GUI build remains unverified. The Release app compiles directly against the macOS SDK with a macOS 13 deployment target and is ad-hoc signed without App Sandbox.

Automated checks (`./macos/test.sh`):

- Stub Claude success and exact original CLI arguments.
- Stub Codex failure and preserved ephemeral/read-only arguments.
- Executable and output paths containing spaces.
- Missing executable records exit 127.
- Concurrent invocations send one greeting; duplicate reports Already running.
- CLI exit 75 remains a failure rather than being mistaken for overlap.
- Stale lock file does not prevent a new run; kernel lock controls ownership.
- Settings round-trip, weekday plist generation, RunAtLoad false, installed schedule inspection.
- Provider independence, disabling after CLI removal, invalid executable rejection.
- Injected bootstrap failure restores old plist, runner, loaded state, and saved settings; a second injected failure surfaces rollback failure explicitly.
- Unsupported trigger detection.

Local installation: `~/Applications/Auto Session Start.app`. LaunchServices accepted opening the Applications copy; its running executable path and code signature were verified. Both existing jobs were migrated under their original labels, preserving enabled weekday times (Claude 08:30, Codex 08:00). Original plists are backed up in app support; legacy scripts and logs remain intact. No real CLI greeting was sent during implementation.

UI checks passed against the Applications copy: main window and Settings render correctly; both installed times are shown; closing and activating recreates the main window; Command-Q exits the process while its LaunchAgents stay loaded. A Claude toggle shows unapplied changes before Apply, and applying disabled only Claude. Run now executed a local stub while Claude was disabled. The success record and disabled state survived quitting and reopening. Codex remained enabled throughout. Both original enabled states were restored afterward, and the stub-only log/status were moved to the ignored build directory so they are not mistaken for real service greetings. No real CLI request was sent.

A refresh-related brief button-disable issue discovered during UI checks was fixed in the final build. Native UI automation was intermittently unavailable. File-picker interaction, literal Finder double-click, and Dock/app-switcher visual inspection remain manual checks; LaunchServices launching and the regular window/activation behavior were exercised. There is no MenuBarExtra or status-item implementation.

Logout/login and sleeping/waking were not performed. Disabled persistence is verified structurally by removing the plist and unloading the job. The app was built on macOS 26; execution on macOS 13 itself has not been tested.

The opt-in `python3 macos/tests/test_launchd.py` creates a unique temporary user job, waits for a calendar minute, checks a local stub, and removes the job. It never uses the real provider labels or services.

Real launchd integration passed: loading the temporary job did not send a greeting; the next calendar minute executed a copied standalone runner and local stub successfully. The test job was unloaded and removed. An initial version referencing the runner inside Documents failed to run; copying the runner to an independent location fixed the test, matching the production app-support layout.
