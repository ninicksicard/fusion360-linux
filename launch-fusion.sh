#!/bin/bash
set -Eeuo pipefail

fail() {
  echo "launch-fusion.sh failed: $*" >&2
  exit 1
}

on_error() {
  echo "launch-fusion.sh failed near line $1: $2" >&2
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fusion360-linux"
CONFIG_FILE="$CONFIG_DIR/config"

PROTON="${PROTON:-$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton}"
STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/.fusion360-proton2}"
STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.local/share/Steam}"
FUSION_ROOT="${FUSION_ROOT:-$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production}"
BROWSER="${BROWSER:-$SCRIPT_DIR/fusion-browser.sh}"
CHROME="${CHROME:-/usr/bin/google-chrome}"

load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  source "$CONFIG_FILE"
}

save_config() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF_CONFIG
PROTON=$(printf "%q" "$PROTON")
STEAM_COMPAT_DATA_PATH=$(printf "%q" "$STEAM_COMPAT_DATA_PATH")
STEAM_COMPAT_CLIENT_INSTALL_PATH=$(printf "%q" "$STEAM_COMPAT_CLIENT_INSTALL_PATH")
FUSION_ROOT=$(printf "%q" "$FUSION_ROOT")
BROWSER=$(printf "%q" "$BROWSER")
CHROME=$(printf "%q" "$CHROME")
EOF_CONFIG
}

select_file() {
  local title="$1"
  local current_path="$2"
  local selected_path
  if ! selected_path="$(zenity --file-selection --title="$title" --filename="$current_path")"; then
    fail "No file selected for: $title"
  fi
  [[ -n "$selected_path" ]] || fail "No file selected for: $title"
  printf "%s" "$selected_path"
}

select_directory() {
  local title="$1"
  local current_path="$2"
  local selected_path
  if ! selected_path="$(zenity --file-selection --directory --title="$title" --filename="$current_path")"; then
    fail "No directory selected for: $title"
  fi
  [[ -n "$selected_path" ]] || fail "No directory selected for: $title"
  printf "%s" "$selected_path"
}

show_selection_summary() {
  cat <<EOF_SUMMARY
Fusion 360 launch selections:
  Proton executable: $PROTON
  Proton prefix: $STEAM_COMPAT_DATA_PATH
  Steam install directory: $STEAM_COMPAT_CLIENT_INSTALL_PATH
  Fusion production directory: $FUSION_ROOT
  Browser bridge script: $BROWSER
  Chrome executable: $CHROME
EOF_SUMMARY
}

configure_with_file_browsers() {
  command -v zenity >/dev/null 2>&1 || fail "zenity is required for file browser selection. Install zenity or set PROTON, STEAM_COMPAT_DATA_PATH, STEAM_COMPAT_CLIENT_INSTALL_PATH, FUSION_ROOT, BROWSER, and CHROME environment variables."

  zenity --info --title="Fusion 360 launcher setup" --text="Select each path used to launch Fusion 360. The next dialogs will clearly name the item being selected."
  PROTON="$(select_file "Select the Proton executable" "$PROTON")"
  STEAM_COMPAT_DATA_PATH="$(select_directory "Select the Proton prefix directory" "$STEAM_COMPAT_DATA_PATH")"
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$(select_directory "Select the Steam install directory" "$STEAM_COMPAT_CLIENT_INSTALL_PATH")"
  FUSION_ROOT="$(select_directory "Select the Fusion production directory" "$FUSION_ROOT")"
  BROWSER="$(select_file "Select the browser bridge script" "$BROWSER")"
  CHROME="$(select_file "Select the Chrome executable" "$CHROME")"

  show_selection_summary
  zenity --question --title="Save Fusion 360 launcher setup" --text="$(show_selection_summary)

Save these selections?" || fail "Setup was cancelled."
  save_config
}

load_config

if [[ "${1:-}" == "--configure" ]]; then
  configure_with_file_browsers
  exit 0
fi

missing_selection=0
[[ -x "$PROTON" ]] || missing_selection=1
[[ -x "$BROWSER" ]] || missing_selection=1
[[ -x "$CHROME" ]] || missing_selection=1
[[ -d "$FUSION_ROOT" ]] || missing_selection=1

if [[ $missing_selection -eq 1 && -t 1 && -n "${DISPLAY:-}" && -z "${FUSION_SKIP_UI:-}" ]]; then
  configure_with_file_browsers
fi

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export BROWSER
export CHROME
export WINEDLLOVERRIDES="bcp47langs="
# Previous safe-login fallback:
# export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--disable-gpu --no-sandbox"
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox"
export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH

[[ -x "$PROTON" ]] || fail "Proton was not found or is not executable: $PROTON. Run $0 --configure to select it."
[[ -x "$BROWSER" ]] || fail "Browser bridge was not found or is not executable: $BROWSER. Run $0 --configure to select it."
[[ -x "$CHROME" ]] || fail "Chrome was not found or is not executable: $CHROME. Run $0 --configure to select it."
[[ -d "$FUSION_ROOT" ]] || fail "Fusion production directory was not found: $FUSION_ROOT. Run $0 --configure to select it."

FUSION_EXE="$(find "$FUSION_ROOT" -maxdepth 2 -name Fusion360.exe -print | sort | tail -n 1)"
[[ -n "$FUSION_EXE" ]] || fail "Fusion360.exe was not found under $FUSION_ROOT"

FUSION_DIR="$(dirname "$FUSION_EXE")"
PRODUCTION_CONFIG="$FUSION_DIR/Applications/Fusion/Fusion360App/ApplicationOptions.production.json"
SERVER_CONFIG="$FUSION_DIR/Fusion 360.server.config"

if [[ -f "$PRODUCTION_CONFIG" ]]; then
  cp "$PRODUCTION_CONFIG" "$SERVER_CONFIG"
else
  echo "launch-fusion.sh warning: production config was not found: $PRODUCTION_CONFIG" >&2
fi

set +e
"$PROTON" run "$FUSION_EXE" "$@"
status=$?
set -e
[[ $status -eq 0 ]] || fail "Fusion exited or crashed with status $status"
