#!/usr/bin/env bash
# fusion-browser.sh: Fusion 360 browser bridge request writer.

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fusion360-linux/config"
REQUEST_DIR="/tmp/fusion360-browser-requests"
LOG_FILE="/tmp/fusion-browser-bridge.log"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

mkdir -p "$REQUEST_DIR"

{
  echo "============================================================"
  echo "timestamp=$(date -Is)"
  echo "script=$0"
  echo "pid=$$"
  echo "ppid=$PPID"
  echo "pwd=$PWD"
  echo "argc=$#"

  argument_index=0
  for argument in "$@"; do
    printf 'argv[%d]=%q\n' "$argument_index" "$argument"
    argument_index=$((argument_index + 1))
  done
} >> "$LOG_FILE" 2>&1

if [[ $# -lt 1 ]]; then
  echo "no url argument received" >> "$LOG_FILE"
  echo "============================================================" >> "$LOG_FILE"
  echo >> "$LOG_FILE"
  exit 0
fi

request_name="$(date +%s.%N).$$"
partial_file="$REQUEST_DIR/$request_name.partial"
request_file="$REQUEST_DIR/$request_name.request"

printf "%s\n" "$1" > "$partial_file"
mv "$partial_file" "$request_file"

{
  echo "wrote_request=$request_file"
  echo "============================================================"
  echo
} >> "$LOG_FILE" 2>&1

exit 0