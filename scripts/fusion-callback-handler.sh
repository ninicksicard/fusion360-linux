#!/usr/bin/env bash
# fusion-callback-handler.sh: Fusion 360 Autodesk callback request writer.

CALLBACK_DIR="/tmp/fusion360-callback-requests"
LOG_FILE="/tmp/fusion-callback-handler.log"

mkdir -p "$CALLBACK_DIR"

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
  echo "no callback url received" >> "$LOG_FILE"
  echo "============================================================" >> "$LOG_FILE"
  echo >> "$LOG_FILE"
  exit 0
fi

request_name="$(date +%s.%N).$$"
partial_file="$CALLBACK_DIR/$request_name.partial"
request_file="$CALLBACK_DIR/$request_name.request"

printf "%s\n" "$1" > "$partial_file"
mv "$partial_file" "$request_file"

{
  echo "wrote_callback_request=$request_file"
  echo "============================================================"
  echo
} >> "$LOG_FILE" 2>&1

exit 0