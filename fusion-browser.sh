#!/bin/bash
set -euo pipefail
BROWSER_EXECUTABLE="${BROWSER_EXECUTABLE:-/usr/bin/google-chrome}"
BROWSER_LOG_FILE="${BROWSER_LOG_FILE:-/tmp/fusion-browser.log}"
printf "%s\n" "$(date -Is) $*" >> "$BROWSER_LOG_FILE"
exec "$BROWSER_EXECUTABLE" --new-window "$@"
