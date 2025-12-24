# Claude Pro Timer Automation

Automatically sends a message to Claude Pro every morning at 8:00 AM to start the 5-hour usage timer. So that we can fit 3 5-hr claude session on a normal workday.

### Files

1. **~/bin/start-claude-timer.sh** - Main execution script
2. **~/Library/LaunchAgents/com.user.claude.timer.plist** - launchd scheduler configuration
3. **~/bin/logs/** - Log directory for automation output

### How It Works

- Every day at 8:00 AM, macOS launchd triggers the script
- The script sends "Good morning" to Claude Code CLI
- This starts your 5-hour usage timer
- Logs are saved to `~/bin/logs/stdout.log`

### No Need to Keep Anything Running

You don't need to keep Claude Code, this project, or any terminal window open. The automation runs completely in the background via macOS launchd. Just have your computer powered on at 8:00 AM (or it will run when you wake it up).

## Status Check

To verify the automation is running:

```bash
# Check if job is loaded
launchctl list | grep claude.timer

# View recent logs
tail -20 ~/bin/logs/stdout.log

# View errors (if any)
tail -20 ~/bin/logs/stderr.log
```

## Manual Trigger

To test immediately without waiting for 8:00 AM:

```bash
launchctl start com.user.claude.timer
```

Then check the logs:

```bash
cat ~/bin/logs/stdout.log
```

## Verify Next Scheduled Run

```bash
launchctl print user/$(id -u)/com.user.claude.timer
```

## Logs Location

- **~/bin/logs/stdout.log** - Script execution and Claude responses
- **~/bin/logs/stderr.log** - Error messages (if any)
- **~/bin/logs/launchd-stderr.log** - launchd errors (if any)

## Uninstall

To remove the automation:

```bash
# Unload the job
launchctl unload ~/Library/LaunchAgents/com.user.claude.timer.plist

# Remove the files
rm ~/Library/LaunchAgents/com.user.claude.timer.plist
rm ~/bin/start-claude-timer.sh
rm -rf ~/bin/logs
```

## Troubleshooting

**Job not running:**

```bash
launchctl list | grep claude.timer
```

**Computer asleep at 8 AM:**

- launchd will execute the job when your computer wakes up

**Authentication issues:**

- If Claude CLI token expires, re-authenticate:
  ```bash
  claude setup-token
  ```

## Test Results

Latest test (2025-12-23 12:13:55):

```
[2025-12-23 12:13:55] Starting Claude timer...
Good morning! How can I help you today?
[2025-12-23 12:13:59] Claude timer started successfully
```

Status: ✅ Working perfectly
