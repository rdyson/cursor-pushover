# cursor-pushover

Send Cursor completion notifications on macOS to [Pushover](https://pushover.net) so you get a push notification on your phone when Cursor finishes.

## What this does

`cursor-pushover.sh` watches macOS notification logs for Cursor notifications, then calls `generic-pushover.sh` to send a Pushover message.

This currently works best when:

- Cursor notifications are enabled
- Cursor is hidden or in the background while the task runs

## Quick start

### 1. Clone the repo

```zsh
git clone https://github.com/rdyson/cursor-pushover.git
cd cursor-pushover
```

### 2. Add your Pushover secrets

#### Option A: macOS Keychain

```zsh
security add-generic-password -U -a "$USER" -s PUSHOVER_TOKEN -w 'your-pushover-app-token'
security add-generic-password -U -a "$USER" -s PUSHOVER_USER -w 'your-pushover-user-key'
```

#### Option B: environment variables

```zsh
export PUSHOVER_TOKEN="your-pushover-app-token"
export PUSHOVER_USER="your-pushover-user-key"
```

If you want those available in every Terminal session, add them to `~/.zshrc` and reload:

```zsh
source ~/.zshrc
```

### 3. Test Pushover directly

```zsh
./generic-pushover.sh "cursor-pushover test"
```

You should receive a push notification.

### 4. Start the watcher

```zsh
./cursor-pushover.sh
```

### 5. Start a Cursor task, then hide Cursor

After starting the agent task in Cursor:

- hide Cursor with `Cmd-H`, or
- switch to another app / desktop

When Cursor finishes and macOS posts the notification, `cursor-pushover.sh` should relay it to Pushover.

## Files

- `cursor-pushover.sh` — watches macOS unified logs for Cursor notifications and triggers Pushover
- `generic-pushover.sh` — sends a message using the Pushover API; reusable outside this project too

## Requirements

### `generic-pushover.sh`

- `bash`
- `curl`
- a Pushover account - 10k free messages/month, $5 one-time purchase for each device you'd like to send notifications to
- a Pushover app token
- your Pushover user key

### `cursor-pushover.sh`

- macOS
- Cursor notifications enabled
- access to the macOS `log` command

## Where to get your Pushover values

In Pushover:

- `PUSHOVER_USER` = your **User Key**
- `PUSHOVER_TOKEN` = your application's **API Token/Key**

## Secret setup details

`generic-pushover.sh` loads secrets in this order:

1. environment variables
2. macOS Keychain

So environment variables override Keychain values if both are present.

## Usage

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

1. start `./cursor-pushover.sh`
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

## Known limitations

- macOS only
- depends on Cursor posting a macOS system notification when a task finishes
- on this setup, Cursor needs to be hidden or backgrounded for that notification to appear reliably
- depends on macOS unified log output from `usernoted`, which could change in a future macOS release
- bundle-id auto-detection could fail on some installations, in which case you may need to set `CURSOR_BUNDLE_ID` manually

## Troubleshooting

### `./generic-pushover.sh` fails

Check that your secrets are set correctly.

Test environment variables:

```zsh
echo "$PUSHOVER_TOKEN"
echo "$PUSHOVER_USER"
```

Test Keychain values:

```zsh
security find-generic-password -a "$USER" -s PUSHOVER_TOKEN -w
security find-generic-password -a "$USER" -s PUSHOVER_USER -w
```

### `./cursor-pushover.sh` just sits there

That usually means it is waiting for a matching Cursor notification.

Try:

- make sure Cursor notifications are enabled in macOS
- start a task in Cursor
- hide Cursor
- run with debug logging:

```zsh
DEBUG=1 ./cursor-pushover.sh
```

### You want to confirm macOS is logging Cursor notifications

Run this manually:

```zsh
log stream --style compact --info --predicate 'process == "usernoted"'
```

Then start a Cursor task, hide Cursor, and look for a log line containing Cursor's bundle id.

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
