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

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BROWSER="$SCRIPT_DIR/fusion-browser.sh"
export WINEDLLOVERRIDES="bcp47langs="
# Previous safe-login fallback:
# export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--disable-gpu --no-sandbox"
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox"
export STEAM_COMPAT_DATA_PATH="$HOME/.fusion360-proton2"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"

PROTON="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton"
FUSION_ROOT="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production"

[[ -x "$PROTON" ]] || fail "Proton was not found or is not executable: $PROTON"
[[ -x "$BROWSER" ]] || fail "Browser bridge was not found or is not executable: $BROWSER"
[[ -d "$FUSION_ROOT" ]] || fail "Fusion production directory was not found: $FUSION_ROOT"

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
