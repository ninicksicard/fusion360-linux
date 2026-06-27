#!/bin/bash
set -Eeuo pipefail

fail() {
  echo "fusion-browser.sh failed: $*" >&2
  exit 1
}

on_error() {
  echo "fusion-browser.sh failed near line $1: $2" >&2
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

CHROME=/usr/bin/google-chrome
LOG_FILE=/tmp/fusion-browser.log

[[ -x "$CHROME" ]] || fail "Chrome was not found or is not executable: $CHROME"
printf "%s\n" "$(date -Is) $*" >> "$LOG_FILE"
set +e
"$CHROME" --new-window "$@"
status=$?
set -e
[[ $status -eq 0 ]] || fail "Chrome exited or crashed with status $status"
