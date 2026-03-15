#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MESSAGE="${1:-Cursor agent finished}"
PUSHOVER_SCRIPT="${2:-$SCRIPT_DIR/generic-pushover.sh}"
CURSOR_APP_NAME="${3:-${CURSOR_APP_NAME:-Cursor}}"
CURSOR_BUNDLE_ID="${4:-${CURSOR_BUNDLE_ID:-}}"
DEBUG="${DEBUG:-0}"

log_msg() {
  echo "[cursor-pushover] $*" >&2
}

detect_bundle_id() {
  local app_name="$1"
  local bundle_id=""
  local app_path=""

  if command -v osascript >/dev/null 2>&1; then
    bundle_id="$(osascript -e "try" -e "id of app \"$app_name\"" -e "end try" 2>/dev/null | tr -d '\r')"
    if [[ -n "$bundle_id" ]]; then
      printf '%s\n' "$bundle_id"
      return 0
    fi

    app_path="$(osascript -e "try" -e "POSIX path of (path to application \"$app_name\")" -e "end try" 2>/dev/null | tr -d '\r')"
    if [[ -n "$app_path" && -f "$app_path/Contents/Info.plist" ]]; then
      bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null || true)"
      if [[ -n "$bundle_id" ]]; then
        printf '%s\n' "$bundle_id"
        return 0
      fi
    fi
  fi

  if [[ -d "/Applications/$app_name.app" ]]; then
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "/Applications/$app_name.app/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -n "$bundle_id" ]]; then
      printf '%s\n' "$bundle_id"
      return 0
    fi
  fi

  return 1
}

if [[ ! -x "$PUSHOVER_SCRIPT" ]]; then
  log_msg "Error: notify script is not executable: $PUSHOVER_SCRIPT"
  exit 1
fi

if ! command -v log >/dev/null 2>&1; then
  log_msg "Error: macOS 'log' command is required"
  exit 1
fi

if [[ -z "$CURSOR_BUNDLE_ID" ]]; then
  CURSOR_BUNDLE_ID="$(detect_bundle_id "$CURSOR_APP_NAME" || true)"
fi

if [[ -z "$CURSOR_BUNDLE_ID" ]]; then
  log_msg "Error: could not detect bundle id for app: $CURSOR_APP_NAME"
  log_msg "Try: osascript -e 'id of app \"$CURSOR_APP_NAME\"'"
  log_msg "Or rerun with CURSOR_BUNDLE_ID=... ./cursor-pushover.sh"
  exit 1
fi

PREDICATE="process == \"usernoted\" AND eventMessage CONTAINS[c] \"Added request\" AND eventMessage CONTAINS[c] \"app:\\\"$CURSOR_BUNDLE_ID\\\"\""
MATCH_TEXT="app:\"$CURSOR_BUNDLE_ID\""
last_sent=0

log_msg "Watching notifications for app: $CURSOR_APP_NAME"
log_msg "Using bundle id: $CURSOR_BUNDLE_ID"
log_msg "Using notify script: $PUSHOVER_SCRIPT"
if [[ "$DEBUG" == "1" ]]; then
  log_msg "Using predicate: $PREDICATE"
fi
log_msg "Press Ctrl-C to stop."

while IFS= read -r line; do
  [[ "$line" == *"Added request"* ]] || continue
  [[ "$line" == *"$MATCH_TEXT"* ]] || continue

  if [[ "$DEBUG" == "1" ]]; then
    log_msg "Matched line: $line"
  fi

  now="$(date +%s)"
  if (( now - last_sent < 2 )); then
    if [[ "$DEBUG" == "1" ]]; then
      log_msg "Debounced duplicate event"
    fi
    continue
  fi
  last_sent="$now"

  log_msg "Cursor completion notification detected"

  if ! output="$("$PUSHOVER_SCRIPT" "$MESSAGE" </dev/null 2>&1)"; then
    log_msg "Pushover script failed"
    printf '%s\n' "$output" >&2
    continue
  fi

  if [[ "$DEBUG" == "1" && -n "$output" ]]; then
    log_msg "Pushover response: $output"
  fi
done < <(
  command log stream --style compact --info --predicate "$PREDICATE" 2>/dev/null
)
