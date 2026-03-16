#!/usr/bin/env bash
set -euo pipefail

get_keychain_secret() {
  local service="$1"

  if ! command -v security >/dev/null 2>&1; then
    return 0
  fi

  security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null || true
}

PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-$(get_keychain_secret PUSHOVER_TOKEN)}"
PUSHOVER_USER="${PUSHOVER_USER:-$(get_keychain_secret PUSHOVER_USER)}"

: "${PUSHOVER_TOKEN:?PUSHOVER_TOKEN is required (env var or Keychain item PUSHOVER_TOKEN)}"
: "${PUSHOVER_USER:?PUSHOVER_USER is required (env var or Keychain item PUSHOVER_USER)}"

message="${1:-hello world}"

curl --fail-with-body -sS \
  --form-string "token=$PUSHOVER_TOKEN" \
  --form-string "user=$PUSHOVER_USER" \
  --form-string "message=$message" \
  https://api.pushover.net/1/messages.json
