# cursor-pushover

Relay Cursor completion notifications on macOS to Pushover.

## Files

- `cursor-pushover.sh` — watches macOS unified logs for Cursor notifications and triggers Pushover
- `generic-pushover.sh` — sends a message using the Pushover API; reusable outside this project too

## Requirements

### `generic-pushover.sh`

- `bash`
- `curl`
- a Pushover account
- a Pushover app token
- your Pushover user key

### `cursor-pushover.sh`

- macOS
- Cursor notifications enabled
- access to the macOS `log` command

## Secret setup

### Option 1: environment variables

```zsh
export PUSHOVER_TOKEN="your-pushover-app-token"
export PUSHOVER_USER="your-pushover-user-key"
```

If you use Zsh, you can put those in `~/.zshrc` and reload it:

```zsh
source ~/.zshrc
```

### Option 2: macOS Keychain

`generic-pushover.sh` can read secrets from Keychain.

```zsh
security add-generic-password -U -a "$USER" -s PUSHOVER_TOKEN -w 'your-pushover-app-token'
security add-generic-password -U -a "$USER" -s PUSHOVER_USER -w 'your-pushover-user-key'
```

Environment variables take precedence over Keychain values.

## Usage

Make the scripts executable:

```zsh
chmod +x ./generic-pushover.sh ./cursor-pushover.sh
```

### Send a message directly

```zsh
./generic-pushover.sh "hello from pushover"
```

If no message is provided, it sends `hello world`.

### Watch Cursor completion notifications

Run:

```zsh
./cursor-pushover.sh
```

For debug logging:

```zsh
DEBUG=1 ./cursor-pushover.sh
```

Defaults:

- message: `Cursor agent finished`
- notify script: `./generic-pushover.sh`
- app name: `Cursor`
- bundle id: auto-detected from the installed app

Examples:

```zsh
./cursor-pushover.sh "Cursor is done"
./cursor-pushover.sh "Cursor is done" ./generic-pushover.sh
./cursor-pushover.sh "Cursor is done" ./generic-pushover.sh "Cursor"
```

If bundle-id auto-detection ever fails, override it explicitly:

```zsh
CURSOR_BUNDLE_ID="com.todesktop.230313mzl4w4u92" ./cursor-pushover.sh
```

Or pass it as the fourth argument:

```zsh
./cursor-pushover.sh "Cursor is done" ./generic-pushover.sh "Cursor" "com.todesktop.230313mzl4w4u92"
```

## Important behavior note

On this setup, Cursor only appears to emit the macOS notification when Cursor is hidden or backgrounded. If Cursor is frontmost, the watcher may not see anything because no system notification is posted.

In practice:

1. start the watcher
2. start your Cursor agent task
3. hide Cursor or switch to another app
4. wait for the Pushover notification

## How it works

`cursor-pushover.sh` auto-detects Cursor's bundle id, then runs a command like:

```zsh
log stream --style compact --info --predicate 'process == "usernoted" AND eventMessage CONTAINS[c] "Added request" AND eventMessage CONTAINS[c] "app:\"<bundle-id>\""'
```

It then:

- waits for a matching `usernoted` log line
- debounces events for 2 seconds
- calls `./generic-pushover.sh`

## Run at login with launchd

You can run the watcher automatically when you log in with a LaunchAgent.

### 1. Decide how the script gets secrets

A LaunchAgent does not load your `~/.zshrc`, so shell environment variables will not be present automatically.

Recommended options:

- use macOS Keychain
- or define `EnvironmentVariables` in the plist

### 2. Create a LaunchAgent plist

Create:

`~/Library/LaunchAgents/com.rdyson.cursor-pushover.plist`

Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.rdyson.cursor-pushover</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>/Users/your-macos-username/Code/personal/cursor-pushover/cursor-pushover.sh</string>
      <string>Cursor agent finished</string>
      <string>/Users/your-macos-username/Code/personal/cursor-pushover/generic-pushover.sh</string>
      <string>Cursor</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/cursor-pushover.out.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/cursor-pushover.err.log</string>
  </dict>
</plist>
```

If you do not want to use Keychain, add environment variables in the plist:

```xml
<key>EnvironmentVariables</key>
<dict>
  <key>PUSHOVER_TOKEN</key>
  <string>your-pushover-app-token</string>
  <key>PUSHOVER_USER</key>
  <string>your-pushover-user-key</string>
</dict>
```

If bundle-id auto-detection ever fails under `launchd`, add `CURSOR_BUNDLE_ID` too:

```xml
<key>EnvironmentVariables</key>
<dict>
  <key>PUSHOVER_TOKEN</key>
  <string>your-pushover-app-token</string>
  <key>PUSHOVER_USER</key>
  <string>your-pushover-user-key</string>
  <key>CURSOR_BUNDLE_ID</key>
  <string>com.todesktop.230313mzl4w4u92</string>
</dict>
```

### 3. Load it

```zsh
launchctl unload ~/Library/LaunchAgents/com.rdyson.cursor-pushover.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.rdyson.cursor-pushover.plist
```

On newer macOS versions:

```zsh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.rdyson.cursor-pushover.plist
```

### 4. Check logs

```zsh
tail -f /tmp/cursor-pushover.out.log /tmp/cursor-pushover.err.log
```

To stop it:

```zsh
launchctl unload ~/Library/LaunchAgents/com.rdyson.cursor-pushover.plist
```

## Notes

- `PUSHOVER_USER` is your Pushover user key
- `PUSHOVER_TOKEN` is your Pushover application token
- Keychain lookup is skipped automatically on non-macOS systems
- `cursor-pushover.sh` is the main watcher
- `generic-pushover.sh` can be reused for non-Cursor Pushover notifications
