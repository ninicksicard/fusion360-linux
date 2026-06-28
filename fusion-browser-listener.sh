#!/usr/bin/env bash
# fusion-browser-listener.sh: Fusion 360 browser bridge Linux-side listener.

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fusion360-linux/config"

BROWSER_REQUEST_DIR="/tmp/fusion360-browser-requests"
BROWSER_PROCESSED_DIR="/tmp/fusion360-browser-processed"
CALLBACK_REQUEST_DIR="/tmp/fusion360-callback-requests"
CALLBACK_PROCESSED_DIR="/tmp/fusion360-callback-processed"
LOG_FILE="/tmp/fusion-browser-listener.log"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

mkdir -p "$BROWSER_REQUEST_DIR"
mkdir -p "$BROWSER_PROCESSED_DIR"
mkdir -p "$CALLBACK_REQUEST_DIR"
mkdir -p "$CALLBACK_PROCESSED_DIR"

log_message() {
  printf "%s\n" "$*" >> "$LOG_FILE"
}

find_fusion_executable() {
  find "$FUSION_ROOT" -maxdepth 2 -name Fusion360.exe -print 2>/dev/null | sort | tail -n 1
}

find_identity_manager_executable() {
  local fusion_executable
  local fusion_directory
  local identity_manager_executable

  fusion_executable="$(find_fusion_executable)"
  [[ -n "$fusion_executable" ]] || return 1

  fusion_directory="$(dirname "$fusion_executable")"

  identity_manager_executable="$(find "$fusion_directory" -maxdepth 4 -iname "AdskIdentityManager.exe" -print 2>/dev/null | sort | head -n 1)"

  if [[ -z "$identity_manager_executable" ]]; then
    identity_manager_executable="$(find "$STEAM_COMPAT_DATA_PATH/pfx/drive_c" -iname "AdskIdentityManager.exe" -print 2>/dev/null | sort | head -n 1)"
  fi

  [[ -n "$identity_manager_executable" ]] || return 1
  printf "%s" "$identity_manager_executable"
}

open_browser_url() {
  local request_file="$1"
  local url
  local processed_file
  local open_status

  url="$(cat "$request_file")"
  processed_file="$BROWSER_PROCESSED_DIR/$(basename "$request_file")"

  {
    echo "============================================================"
    echo "timestamp=$(date -Is)"
    echo "type=browser"
    echo "request_file=$request_file"
    printf 'url=%q\n' "$url"
  } >> "$LOG_FILE" 2>&1

  cd "$HOME" || return 1

  env -i \
    HOME="$HOME" \
    USER="$USER" \
    LOGNAME="$USER" \
    SHELL="/bin/bash" \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}" \
    XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-}" \
    XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    LANG="${LANG:-en_CA.UTF-8}" \
    xdg-open "$url" >> "$LOG_FILE" 2>&1

  open_status=$?

  {
    echo "open_status=$open_status"
    echo "processed_file=$processed_file"
    echo "============================================================"
    echo
  } >> "$LOG_FILE" 2>&1

  mv "$request_file" "$processed_file"
}

send_callback_to_identity_manager() {
  local request_file="$1"
  local callback_url
  local processed_file
  local identity_manager_executable
  local callback_status

  callback_url="$(cat "$request_file")"
  processed_file="$CALLBACK_PROCESSED_DIR/$(basename "$request_file")"

  {
    echo "============================================================"
    echo "timestamp=$(date -Is)"
    echo "type=callback"
    echo "request_file=$request_file"
    printf 'callback_url=%q\n' "$callback_url"
  } >> "$LOG_FILE" 2>&1

  identity_manager_executable="$(find_identity_manager_executable)"

  if [[ -z "$identity_manager_executable" ]]; then
    echo "identity_manager_executable=NOT_FOUND" >> "$LOG_FILE"
    echo "============================================================" >> "$LOG_FILE"
    echo >> "$LOG_FILE"
    mv "$request_file" "$processed_file"
    return 1
  fi

  {
    echo "identity_manager_executable=$identity_manager_executable"
  } >> "$LOG_FILE" 2>&1

  export PROTON_USE_WINED3D=0
  export PROTON_USE_XALIA=0
  export DXVK_ASYNC=1
  export NO_AT_BRIDGE=1
  export WINEDLLOVERRIDES="bcp47langs="
  export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox"
  export STEAM_COMPAT_DATA_PATH
  export STEAM_COMPAT_CLIENT_INSTALL_PATH

  "$PROTON" run "$identity_manager_executable" "$callback_url" >> "$LOG_FILE" 2>&1
  callback_status=$?

  {
    echo "callback_status=$callback_status"
    echo "processed_file=$processed_file"
    echo "============================================================"
    echo
  } >> "$LOG_FILE" 2>&1

  mv "$request_file" "$processed_file"
}

process_browser_requests() {
  local request_file

  for request_file in "$BROWSER_REQUEST_DIR"/*.request; do
    [[ -e "$request_file" ]] || continue
    open_browser_url "$request_file"
  done
}

process_callback_requests() {
  local request_file

  for request_file in "$CALLBACK_REQUEST_DIR"/*.request; do
    [[ -e "$request_file" ]] || continue
    send_callback_to_identity_manager "$request_file"
  done
}

log_message "fusion-browser-listener.sh started at $(date -Is)"
log_message "watching $BROWSER_REQUEST_DIR"
log_message "watching $CALLBACK_REQUEST_DIR"

while true; do
  process_browser_requests
  process_callback_requests
  sleep 0.2
done