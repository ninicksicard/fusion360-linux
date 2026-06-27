#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_DIRECTORY="${XDG_CONFIG_HOME:-$HOME/.config}/fusion360-linux"
SETTINGS_FILE="$SETTINGS_DIRECTORY/settings"

fusion_prompt_text() {
  local title="$1"
  local text="$2"
  local current_value="$3"
  local answer=""

  if command -v zenity >/dev/null 2>&1; then
    answer="$(zenity --entry --title="$title" --text="$text" --entry-text="$current_value")"
  elif command -v kdialog >/dev/null 2>&1; then
    answer="$(kdialog --title "$title" --inputbox "$text" "$current_value")"
  else
    printf "%s [%s]: " "$text" "$current_value" >&2
    read -r answer
    if [[ -z "$answer" ]]; then
      answer="$current_value"
    fi
  fi

  printf "%s" "$answer"
}

fusion_prompt_file() {
  local title="$1"
  local current_value="$2"
  local answer=""

  if command -v zenity >/dev/null 2>&1; then
    answer="$(zenity --file-selection --title="$title" --filename="$current_value")"
  elif command -v kdialog >/dev/null 2>&1; then
    answer="$(kdialog --title "$title" --getopenfilename "$(dirname "$current_value")")"
  else
    fusion_prompt_text "$title" "$title" "$current_value"
    return
  fi

  printf "%s" "$answer"
}

fusion_prompt_directory() {
  local title="$1"
  local current_value="$2"
  local answer=""

  if command -v zenity >/dev/null 2>&1; then
    answer="$(zenity --file-selection --directory --title="$title" --filename="$current_value")"
  elif command -v kdialog >/dev/null 2>&1; then
    answer="$(kdialog --title "$title" --getexistingdirectory "$current_value")"
  else
    fusion_prompt_text "$title" "$title" "$current_value"
    return
  fi

  printf "%s" "$answer"
}

fusion_write_settings() {
  mkdir -p "$SETTINGS_DIRECTORY"
  {
    printf "PROTON_EXECUTABLE=%q\n" "$PROTON_EXECUTABLE"
    printf "STEAM_COMPAT_DATA_PATH=%q\n" "$STEAM_COMPAT_DATA_PATH"
    printf "STEAM_COMPAT_CLIENT_INSTALL_PATH=%q\n" "$STEAM_COMPAT_CLIENT_INSTALL_PATH"
    printf "FUSION_PRODUCTION_DIRECTORY=%q\n" "$FUSION_PRODUCTION_DIRECTORY"
    printf "BROWSER_EXECUTABLE=%q\n" "$BROWSER_EXECUTABLE"
    printf "BROWSER_LOG_FILE=%q\n" "$BROWSER_LOG_FILE"
    printf "WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=%q\n" "$WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"
  } > "$SETTINGS_FILE"
}

fusion_assistant() {
  PROTON_EXECUTABLE="$(fusion_prompt_file "Select Proton executable" "$PROTON_EXECUTABLE")"
  STEAM_COMPAT_DATA_PATH="$(fusion_prompt_directory "Select Proton prefix directory" "$STEAM_COMPAT_DATA_PATH")"
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$(fusion_prompt_directory "Select Steam directory" "$STEAM_COMPAT_CLIENT_INSTALL_PATH")"
  FUSION_PRODUCTION_DIRECTORY="$(fusion_prompt_directory "Select Fusion production directory" "$FUSION_PRODUCTION_DIRECTORY")"
  BROWSER_EXECUTABLE="$(fusion_prompt_file "Select browser executable" "$BROWSER_EXECUTABLE")"
  BROWSER_LOG_FILE="$(fusion_prompt_text "Browser log file" "Browser log file" "$BROWSER_LOG_FILE")"
  WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="$(fusion_prompt_text "WebView2 browser arguments" "WebView2 browser arguments" "$WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS")"
  fusion_write_settings
}

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export BROWSER="$SCRIPT_DIRECTORY/fusion-browser.sh"
export WINEDLLOVERRIDES="bcp47langs="
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox"
export STEAM_COMPAT_DATA_PATH="$HOME/.fusion360-proton2"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
export BROWSER_EXECUTABLE="/usr/bin/google-chrome"
export BROWSER_LOG_FILE="/tmp/fusion-browser.log"

PROTON_EXECUTABLE="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton"
FUSION_PRODUCTION_DIRECTORY="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production"

if [[ -f "$SETTINGS_FILE" ]]; then
  source "$SETTINGS_FILE"
fi

if [[ "${1:-}" == "--assistant" ]]; then
  fusion_assistant
  exit 0
fi

export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH
export BROWSER_EXECUTABLE
export BROWSER_LOG_FILE

FUSION_EXECUTABLE=""
if [[ -d "$FUSION_PRODUCTION_DIRECTORY" ]]; then
  FUSION_EXECUTABLE="$(find "$FUSION_PRODUCTION_DIRECTORY" -maxdepth 2 -name Fusion360.exe | sort | tail -n 1)"
fi

if [[ -z "$FUSION_EXECUTABLE" ]]; then
  echo "Fusion360.exe was not found under $FUSION_PRODUCTION_DIRECTORY" >&2
  echo "Run $0 --assistant to select your Fusion directories." >&2
  exit 1
fi

FUSION_DIRECTORY="$(dirname "$FUSION_EXECUTABLE")"
PRODUCTION_SETTINGS_FILE="$FUSION_DIRECTORY/Applications/Fusion/Fusion360App/ApplicationOptions.production.json"
SERVER_SETTINGS_FILE="$FUSION_DIRECTORY/Fusion 360.server.config"

if [[ -f "$PRODUCTION_SETTINGS_FILE" ]]; then
  cp "$PRODUCTION_SETTINGS_FILE" "$SERVER_SETTINGS_FILE"
fi

exec "$PROTON_EXECUTABLE" run "$FUSION_EXECUTABLE" "$@"
