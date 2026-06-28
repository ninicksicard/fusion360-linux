#!/usr/bin/env bash
# launch-fusion.sh: Launch Fusion 360 through Proton with browser bridge support.

fail() {
  echo "launch-fusion.sh failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fusion360-linux"
CONFIG_FILE="$CONFIG_DIR/config"

PROTON="${PROTON:-$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton}"
STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/.fusion360-proton2}"
STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.local/share/Steam}"
FUSION_ROOT="${FUSION_ROOT:-$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production}"
BROWSER="${BROWSER:-$SCRIPT_DIR/fusion-browser.sh}"
BROWSER_LISTENER="${BROWSER_LISTENER:-$SCRIPT_DIR/fusion-browser-listener.sh}"
CALLBACK_HANDLER="${CALLBACK_HANDLER:-$SCRIPT_DIR/fusion-callback-handler.sh}"
CHROME="${CHROME:-/usr/bin/google-chrome}"
FUSION_OVERLAY_KILLER="${FUSION_OVERLAY_KILLER:-$SCRIPT_DIR/fusion-gray-overlay-event-killer-parent-exit.sh}"
FUSION_WINE_RESTART_SCRIPT="${FUSION_WINE_RESTART_SCRIPT:-$SCRIPT_DIR/kill-wine-proton-fusion-nuclear.sh}"

FUSION_WINE_DPI="${FUSION_WINE_DPI:-auto}"
FUSION_WINE_SCALE_PERCENT="${FUSION_WINE_SCALE_PERCENT:-auto}"
FUSION_WINE_DPI_FALLBACK="${FUSION_WINE_DPI_FALLBACK:-144}"
FUSION_WINE_SCALE_FALLBACK_PERCENT="${FUSION_WINE_SCALE_FALLBACK_PERCENT:-150}"
FUSION_DPI_LOG_FILE="/tmp/fusion360-dpi.log"

FUSION_PROTON_USE_WINED3D="${FUSION_PROTON_USE_WINED3D:-0}"
FUSION_PROTON_USE_XALIA="${FUSION_PROTON_USE_XALIA:-0}"
FUSION_DXVK_ASYNC="${FUSION_DXVK_ASYNC:-1}"
FUSION_NO_AT_BRIDGE="${FUSION_NO_AT_BRIDGE:-1}"
FUSION_FIX_BCP47LANGS="${FUSION_FIX_BCP47LANGS:-1}"
FUSION_WEBVIEW_NO_SANDBOX="${FUSION_WEBVIEW_NO_SANDBOX:-1}"
FUSION_WEBVIEW_DISABLE_GPU="${FUSION_WEBVIEW_DISABLE_GPU:-0}"
FUSION_USE_INTEL_VK_ICD="${FUSION_USE_INTEL_VK_ICD:-1}"
FUSION_ENABLE_OVERLAY_KILLER="${FUSION_ENABLE_OVERLAY_KILLER:-1}"
FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT="${FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT:-25}"

BRIDGE_BROWSER_REQUEST_DIR="/tmp/fusion360-browser-requests"
BRIDGE_BROWSER_PROCESSED_DIR="/tmp/fusion360-browser-processed"
BRIDGE_CALLBACK_REQUEST_DIR="/tmp/fusion360-callback-requests"
BRIDGE_CALLBACK_PROCESSED_DIR="/tmp/fusion360-callback-processed"
BRIDGE_LISTENER_PID=""
OVERLAY_KILLER_PID=""

is_enabled() {
  case "${1:-}" in
    1|yes|true|on|enabled|y|Y|TRUE|True|ON|On)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  source "$CONFIG_FILE"

  BROWSER_LISTENER="${BROWSER_LISTENER:-$SCRIPT_DIR/fusion-browser-listener.sh}"
  CALLBACK_HANDLER="${CALLBACK_HANDLER:-$SCRIPT_DIR/fusion-callback-handler.sh}"
  FUSION_OVERLAY_KILLER="${FUSION_OVERLAY_KILLER:-$SCRIPT_DIR/fusion-gray-overlay-event-killer-parent-exit.sh}"
  FUSION_WINE_RESTART_SCRIPT="${FUSION_WINE_RESTART_SCRIPT:-$SCRIPT_DIR/kill-wine-proton-fusion-nuclear.sh}"

  FUSION_WINE_DPI="${FUSION_WINE_DPI:-auto}"
  FUSION_WINE_SCALE_PERCENT="${FUSION_WINE_SCALE_PERCENT:-auto}"
  FUSION_WINE_DPI_FALLBACK="${FUSION_WINE_DPI_FALLBACK:-144}"
  FUSION_WINE_SCALE_FALLBACK_PERCENT="${FUSION_WINE_SCALE_FALLBACK_PERCENT:-150}"

  FUSION_PROTON_USE_WINED3D="${FUSION_PROTON_USE_WINED3D:-0}"
  FUSION_PROTON_USE_XALIA="${FUSION_PROTON_USE_XALIA:-0}"
  FUSION_DXVK_ASYNC="${FUSION_DXVK_ASYNC:-1}"
  FUSION_NO_AT_BRIDGE="${FUSION_NO_AT_BRIDGE:-1}"
  FUSION_FIX_BCP47LANGS="${FUSION_FIX_BCP47LANGS:-1}"
  FUSION_WEBVIEW_NO_SANDBOX="${FUSION_WEBVIEW_NO_SANDBOX:-1}"
  FUSION_WEBVIEW_DISABLE_GPU="${FUSION_WEBVIEW_DISABLE_GPU:-0}"
  FUSION_USE_INTEL_VK_ICD="${FUSION_USE_INTEL_VK_ICD:-1}"
  FUSION_ENABLE_OVERLAY_KILLER="${FUSION_ENABLE_OVERLAY_KILLER:-1}"
  FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT="${FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT:-25}"
}

save_config() {
  mkdir -p "$CONFIG_DIR"

  cat > "$CONFIG_FILE" <<EOF_CONFIG
PROTON=$(printf "%q" "$PROTON")
STEAM_COMPAT_DATA_PATH=$(printf "%q" "$STEAM_COMPAT_DATA_PATH")
STEAM_COMPAT_CLIENT_INSTALL_PATH=$(printf "%q" "$STEAM_COMPAT_CLIENT_INSTALL_PATH")
FUSION_ROOT=$(printf "%q" "$FUSION_ROOT")
BROWSER=$(printf "%q" "$BROWSER")
BROWSER_LISTENER=$(printf "%q" "$BROWSER_LISTENER")
CALLBACK_HANDLER=$(printf "%q" "$CALLBACK_HANDLER")
CHROME=$(printf "%q" "$CHROME")
FUSION_OVERLAY_KILLER=$(printf "%q" "$FUSION_OVERLAY_KILLER")
FUSION_WINE_RESTART_SCRIPT=$(printf "%q" "$FUSION_WINE_RESTART_SCRIPT")
FUSION_WINE_DPI=$(printf "%q" "$FUSION_WINE_DPI")
FUSION_WINE_SCALE_PERCENT=$(printf "%q" "$FUSION_WINE_SCALE_PERCENT")
FUSION_WINE_DPI_FALLBACK=$(printf "%q" "$FUSION_WINE_DPI_FALLBACK")
FUSION_WINE_SCALE_FALLBACK_PERCENT=$(printf "%q" "$FUSION_WINE_SCALE_FALLBACK_PERCENT")
FUSION_PROTON_USE_WINED3D=$(printf "%q" "$FUSION_PROTON_USE_WINED3D")
FUSION_PROTON_USE_XALIA=$(printf "%q" "$FUSION_PROTON_USE_XALIA")
FUSION_DXVK_ASYNC=$(printf "%q" "$FUSION_DXVK_ASYNC")
FUSION_NO_AT_BRIDGE=$(printf "%q" "$FUSION_NO_AT_BRIDGE")
FUSION_FIX_BCP47LANGS=$(printf "%q" "$FUSION_FIX_BCP47LANGS")
FUSION_WEBVIEW_NO_SANDBOX=$(printf "%q" "$FUSION_WEBVIEW_NO_SANDBOX")
FUSION_WEBVIEW_DISABLE_GPU=$(printf "%q" "$FUSION_WEBVIEW_DISABLE_GPU")
FUSION_USE_INTEL_VK_ICD=$(printf "%q" "$FUSION_USE_INTEL_VK_ICD")
FUSION_ENABLE_OVERLAY_KILLER=$(printf "%q" "$FUSION_ENABLE_OVERLAY_KILLER")
FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT=$(printf "%q" "$FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT")
EOF_CONFIG
}

configure_with_file_browsers() {
  local ui_mode="${1:-hold}"

  command -v python3 >/dev/null 2>&1 || fail "python3 is required for the setup UI."

  PROTON="$PROTON" \
  STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_COMPAT_CLIENT_INSTALL_PATH" \
  FUSION_ROOT="$FUSION_ROOT" \
  BROWSER="$BROWSER" \
  BROWSER_LISTENER="$BROWSER_LISTENER" \
  CALLBACK_HANDLER="$CALLBACK_HANDLER" \
  CHROME="$CHROME" \
  FUSION_OVERLAY_KILLER="$FUSION_OVERLAY_KILLER" \
  FUSION_WINE_RESTART_SCRIPT="$FUSION_WINE_RESTART_SCRIPT" \
  FUSION_WINE_DPI="$FUSION_WINE_DPI" \
  FUSION_WINE_SCALE_PERCENT="$FUSION_WINE_SCALE_PERCENT" \
  FUSION_WINE_DPI_FALLBACK="$FUSION_WINE_DPI_FALLBACK" \
  FUSION_WINE_SCALE_FALLBACK_PERCENT="$FUSION_WINE_SCALE_FALLBACK_PERCENT" \
  FUSION_PROTON_USE_WINED3D="$FUSION_PROTON_USE_WINED3D" \
  FUSION_PROTON_USE_XALIA="$FUSION_PROTON_USE_XALIA" \
  FUSION_DXVK_ASYNC="$FUSION_DXVK_ASYNC" \
  FUSION_NO_AT_BRIDGE="$FUSION_NO_AT_BRIDGE" \
  FUSION_FIX_BCP47LANGS="$FUSION_FIX_BCP47LANGS" \
  FUSION_WEBVIEW_NO_SANDBOX="$FUSION_WEBVIEW_NO_SANDBOX" \
  FUSION_WEBVIEW_DISABLE_GPU="$FUSION_WEBVIEW_DISABLE_GPU" \
  FUSION_USE_INTEL_VK_ICD="$FUSION_USE_INTEL_VK_ICD" \
  FUSION_ENABLE_OVERLAY_KILLER="$FUSION_ENABLE_OVERLAY_KILLER" \
  FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT="$FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT" \
  python3 - "$CONFIG_FILE" "$ui_mode" <<'PY_CONFIG_UI'
import os
import shlex
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog, messagebox

config_file = sys.argv[1]
ui_mode = sys.argv[2] if len(sys.argv) > 2 else "hold"

CONFIG_KEYS = [
    "PROTON",
    "STEAM_COMPAT_DATA_PATH",
    "STEAM_COMPAT_CLIENT_INSTALL_PATH",
    "FUSION_ROOT",
    "BROWSER",
    "BROWSER_LISTENER",
    "CALLBACK_HANDLER",
    "CHROME",
    "FUSION_OVERLAY_KILLER",
    "FUSION_WINE_RESTART_SCRIPT",
    "FUSION_WINE_DPI",
    "FUSION_WINE_SCALE_PERCENT",
    "FUSION_WINE_DPI_FALLBACK",
    "FUSION_WINE_SCALE_FALLBACK_PERCENT",
    "FUSION_PROTON_USE_WINED3D",
    "FUSION_PROTON_USE_XALIA",
    "FUSION_DXVK_ASYNC",
    "FUSION_NO_AT_BRIDGE",
    "FUSION_FIX_BCP47LANGS",
    "FUSION_WEBVIEW_NO_SANDBOX",
    "FUSION_WEBVIEW_DISABLE_GPU",
    "FUSION_USE_INTEL_VK_ICD",
    "FUSION_ENABLE_OVERLAY_KILLER",
    "FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT",
]

RESTART_REQUIRED_KEYS = {
    "PROTON",
    "STEAM_COMPAT_DATA_PATH",
    "STEAM_COMPAT_CLIENT_INSTALL_PATH",
    "FUSION_WINE_SCALE_PERCENT",
    "FUSION_WINE_SCALE_FALLBACK_PERCENT",
    "FUSION_WINE_DPI",
    "FUSION_WINE_DPI_FALLBACK",
    "FUSION_PROTON_USE_WINED3D",
    "FUSION_PROTON_USE_XALIA",
    "FUSION_DXVK_ASYNC",
    "FUSION_NO_AT_BRIDGE",
    "FUSION_FIX_BCP47LANGS",
    "FUSION_WEBVIEW_NO_SANDBOX",
    "FUSION_WEBVIEW_DISABLE_GPU",
    "FUSION_USE_INTEL_VK_ICD",
}


def getenv(name, default=""):
    return os.environ.get(name, default)


def read_gsettings_number(schema_name, key_name):
    try:
        result = subprocess.run(
            ["gsettings", "get", schema_name, key_name],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except FileNotFoundError:
        return None

    for token in result.stdout.replace("'", " ").split():
        try:
            return float(token)
        except ValueError:
            pass

    return None


def percent_to_dpi(percent):
    return int((96 * int(percent) / 100) + 0.5)


def dpi_to_percent(dpi):
    return int((int(dpi) * 100 / 96) + 0.5)


def detected_cinnamon_scale_percent():
    text_scale = read_gsettings_number("org.cinnamon.desktop.interface", "text-scaling-factor")
    window_scale = read_gsettings_number("org.cinnamon.desktop.interface", "scaling-factor")

    if text_scale and text_scale > 0 and text_scale != 1:
        return int((text_scale * 100) + 0.5)

    if window_scale and window_scale > 1:
        return int((window_scale * 100) + 0.5)

    return None


def initial_scale_percent():
    scale_percent = getenv("FUSION_WINE_SCALE_PERCENT", "auto")
    legacy_dpi = getenv("FUSION_WINE_DPI", "auto")
    fallback_scale_percent = getenv("FUSION_WINE_SCALE_FALLBACK_PERCENT", "150")
    legacy_fallback_dpi = getenv("FUSION_WINE_DPI_FALLBACK", "144")

    if scale_percent.isdigit():
        return int(scale_percent)

    if legacy_dpi.isdigit():
        return dpi_to_percent(legacy_dpi)

    detected_scale = detected_cinnamon_scale_percent()
    if detected_scale:
        return detected_scale

    if fallback_scale_percent.isdigit():
        return int(fallback_scale_percent)

    if legacy_fallback_dpi.isdigit():
        return dpi_to_percent(legacy_fallback_dpi)

    return 150


paths = {
    "PROTON": getenv("PROTON"),
    "STEAM_COMPAT_DATA_PATH": getenv("STEAM_COMPAT_DATA_PATH"),
    "STEAM_COMPAT_CLIENT_INSTALL_PATH": getenv("STEAM_COMPAT_CLIENT_INSTALL_PATH"),
    "FUSION_ROOT": getenv("FUSION_ROOT"),
    "BROWSER": getenv("BROWSER"),
    "BROWSER_LISTENER": getenv("BROWSER_LISTENER"),
    "CALLBACK_HANDLER": getenv("CALLBACK_HANDLER"),
    "CHROME": getenv("CHROME"),
    "FUSION_OVERLAY_KILLER": getenv("FUSION_OVERLAY_KILLER"),
    "FUSION_WINE_RESTART_SCRIPT": getenv("FUSION_WINE_RESTART_SCRIPT"),
    "FUSION_WINE_DPI": getenv("FUSION_WINE_DPI", "auto"),
    "FUSION_WINE_SCALE_PERCENT": getenv("FUSION_WINE_SCALE_PERCENT", "auto"),
    "FUSION_WINE_DPI_FALLBACK": getenv("FUSION_WINE_DPI_FALLBACK", "144"),
    "FUSION_WINE_SCALE_FALLBACK_PERCENT": getenv("FUSION_WINE_SCALE_FALLBACK_PERCENT", "150"),
    "FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT": getenv("FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT", "25"),
}

flags = {
    "FUSION_PROTON_USE_WINED3D": getenv("FUSION_PROTON_USE_WINED3D", "0"),
    "FUSION_PROTON_USE_XALIA": getenv("FUSION_PROTON_USE_XALIA", "0"),
    "FUSION_DXVK_ASYNC": getenv("FUSION_DXVK_ASYNC", "1"),
    "FUSION_NO_AT_BRIDGE": getenv("FUSION_NO_AT_BRIDGE", "1"),
    "FUSION_FIX_BCP47LANGS": getenv("FUSION_FIX_BCP47LANGS", "1"),
    "FUSION_WEBVIEW_NO_SANDBOX": getenv("FUSION_WEBVIEW_NO_SANDBOX", "1"),
    "FUSION_WEBVIEW_DISABLE_GPU": getenv("FUSION_WEBVIEW_DISABLE_GPU", "0"),
    "FUSION_USE_INTEL_VK_ICD": getenv("FUSION_USE_INTEL_VK_ICD", "1"),
    "FUSION_ENABLE_OVERLAY_KILLER": getenv("FUSION_ENABLE_OVERLAY_KILLER", "1"),
}

path_rows = [
    ("Proton executable", "PROTON", "file"),
    ("Proton prefix", "STEAM_COMPAT_DATA_PATH", "dir"),
    ("Steam install directory", "STEAM_COMPAT_CLIENT_INSTALL_PATH", "dir"),
    ("Fusion production directory", "FUSION_ROOT", "dir"),
    ("Browser bridge script", "BROWSER", "file"),
    ("Browser listener script", "BROWSER_LISTENER", "file"),
    ("Callback handler script", "CALLBACK_HANDLER", "file"),
    ("Chrome executable", "CHROME", "file"),
    ("Grey overlay killer script", "FUSION_OVERLAY_KILLER", "file"),
    ("Wine restart script", "FUSION_WINE_RESTART_SCRIPT", "file"),
]

flag_rows = [
    ("Force WineD3D", "FUSION_PROTON_USE_WINED3D"),
    ("Disable Xalia", "FUSION_PROTON_USE_XALIA"),
    ("Enable DXVK async", "FUSION_DXVK_ASYNC"),
    ("Set NO_AT_BRIDGE", "FUSION_NO_AT_BRIDGE"),
    ("Apply bcp47langs override", "FUSION_FIX_BCP47LANGS"),
    ("WebView2 no-sandbox", "FUSION_WEBVIEW_NO_SANDBOX"),
    ("WebView2 disable GPU", "FUSION_WEBVIEW_DISABLE_GPU"),
    ("Force Intel Vulkan ICD", "FUSION_USE_INTEL_VK_ICD"),
    ("Start grey overlay killer", "FUSION_ENABLE_OVERLAY_KILLER"),
]


def as_bool(value):
    return str(value).lower() in ("1", "yes", "true", "on", "enabled")


def normalized_flag_value(value):
    return "1" if as_bool(value) else "0"


saved_values = {}
for _, key, _ in path_rows:
    saved_values[key] = paths.get(key, "")
saved_values["FUSION_WINE_SCALE_PERCENT"] = paths["FUSION_WINE_SCALE_PERCENT"]
saved_values["FUSION_WINE_SCALE_FALLBACK_PERCENT"] = paths["FUSION_WINE_SCALE_FALLBACK_PERCENT"]
saved_values["FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT"] = paths["FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT"]
saved_values["FUSION_WINE_DPI"] = paths["FUSION_WINE_DPI"]
saved_values["FUSION_WINE_DPI_FALLBACK"] = paths["FUSION_WINE_DPI_FALLBACK"]
for key, value in flags.items():
    saved_values[key] = normalized_flag_value(value)

root = tk.Tk()
root.title("Fusion 360 launcher setup")
root.minsize(1080, 460)

entries = {}
flag_vars = {}
warning_labels = {}
revert_buttons = {}
status_warning_var = tk.StringVar()

main = tk.Frame(root, padx=12, pady=12)
main.pack(fill="both", expand=True)

tk.Label(main, text="Paths", font=("TkDefaultFont", 11, "bold")).grid(row=0, column=0, sticky="w", pady=(0, 8))
tk.Label(main, text="Current / saved value").grid(row=0, column=1, sticky="w", pady=(0, 8))
tk.Label(main, text="Changed").grid(row=0, column=3, sticky="w", pady=(0, 8))


def current_value_for_key(key):
    if key == "FUSION_WINE_SCALE_PERCENT":
        return "auto" if auto_scale_var.get() else str(scale_value_var.get())

    if key in entries:
        return entries[key].get().strip()

    if key in flag_vars:
        return "1" if flag_vars[key].get() else "0"

    if key == "FUSION_WINE_DPI":
        return "auto"

    if key == "FUSION_WINE_DPI_FALLBACK":
        fallback_scale = entries.get("FUSION_WINE_SCALE_FALLBACK_PERCENT")
        if fallback_scale is not None and fallback_scale.get().strip().isdigit():
            return str(percent_to_dpi(fallback_scale.get().strip()))
        return saved_values.get(key, "")

    return ""


def displayed_keys():
    keys = [key for _, key, _ in path_rows]
    keys.extend([
        "FUSION_WINE_SCALE_PERCENT",
        "FUSION_WINE_SCALE_FALLBACK_PERCENT",
        "FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT",
    ])
    keys.extend([key for _, key in flag_rows])
    return keys


def dirty_keys():
    return [key for key in displayed_keys() if current_value_for_key(key) != saved_values.get(key, "")]


def restart_dirty_keys():
    return [key for key in dirty_keys() if key in RESTART_REQUIRED_KEYS]


def update_global_warning():
    restart_keys = restart_dirty_keys()
    all_dirty_keys = dirty_keys()

    if restart_keys:
        status_warning_var.set("⚠ Wine restart needed for modified launch/Wine settings. Use Save and restart Wine if Fusion is already running.")
    elif all_dirty_keys:
        status_warning_var.set("Unsaved changes.")
    else:
        status_warning_var.set("")


def update_dirty_indicator(key):
    dirty = current_value_for_key(key) != saved_values.get(key, "")

    warning_label = warning_labels.get(key)
    revert_button = revert_buttons.get(key)

    if warning_label is not None:
        if dirty:
            warning_label.config(text="⚠" if key in RESTART_REQUIRED_KEYS else "•")
            warning_label.grid()
        else:
            warning_label.config(text="")
            warning_label.grid_remove()

    if revert_button is not None:
        if dirty:
            revert_button.grid()
        else:
            revert_button.grid_remove()


def update_all_dirty_indicators():
    for key in displayed_keys():
        update_dirty_indicator(key)
    update_global_warning()


def register_dirty_widgets(parent, key, row, warning_column, revert_column):
    warning = tk.Label(parent, text="", width=2, fg="#c27c00")
    warning.grid(row=row, column=warning_column, sticky="w", padx=(6, 0))
    warning.grid_remove()

    revert = tk.Button(parent, text="Revert", width=6, command=lambda selected_key=key: revert_value(selected_key))
    revert.grid(row=row, column=revert_column, sticky="w", padx=(4, 0))
    revert.grid_remove()

    warning_labels[key] = warning
    revert_buttons[key] = revert


def on_value_changed(_event=None):
    stop_countdown()
    update_all_dirty_indicators()


def browse_value(key, kind):
    current = entries[key].get().strip()
    if kind == "dir":
        initialdir = current if os.path.isdir(current) else os.path.expanduser("~")
        selected = filedialog.askdirectory(title=f"Select {key}", initialdir=initialdir)
    else:
        initialdir = current if os.path.isdir(current) else os.path.dirname(current) if current else os.path.expanduser("~")
        selected = filedialog.askopenfilename(title=f"Select {key}", initialdir=initialdir)
    if selected:
        entries[key].delete(0, tk.END)
        entries[key].insert(0, selected)
        on_value_changed()


for row_index, (label, key, kind) in enumerate(path_rows, start=1):
    tk.Label(main, text=label).grid(row=row_index, column=0, sticky="w", padx=(0, 8), pady=3)
    entry = tk.Entry(main, width=100)
    entry.insert(0, paths.get(key, ""))
    entry.grid(row=row_index, column=1, sticky="ew", pady=3)
    entry.bind("<KeyRelease>", on_value_changed, add="+")
    entry.bind("<FocusOut>", on_value_changed, add="+")
    tk.Button(main, text="Browse", command=lambda k=key, t=kind: browse_value(k, t)).grid(row=row_index, column=2, padx=(8, 0), pady=3)
    entries[key] = entry
    register_dirty_widgets(main, key, row_index, 3, 4)

settings_row = len(path_rows) + 2
scale_value_var = tk.IntVar(value=initial_scale_percent())
auto_scale_var = tk.IntVar(value=1 if paths["FUSION_WINE_SCALE_PERCENT"] == "auto" else 0)
scale_label_var = tk.StringVar()


def update_scale_label(_value=None):
    percent = int(scale_value_var.get())
    dpi = percent_to_dpi(percent)
    if auto_scale_var.get():
        scale_label_var.set(f"Auto from Cinnamon/current scale: {percent}% = {dpi} DPI")
    else:
        scale_label_var.set(f"{percent}% = {dpi} DPI")
    update_dirty_indicator("FUSION_WINE_SCALE_PERCENT")
    update_global_warning()


def slider_touched(_event=None):
    auto_scale_var.set(0)
    stop_countdown()
    update_scale_label()


def auto_scale_changed():
    stop_countdown()
    if auto_scale_var.get():
        detected_scale = detected_cinnamon_scale_percent()
        if detected_scale:
            scale_value_var.set(detected_scale)
    update_scale_label()


tk.Label(main, text="Wine scale %").grid(row=settings_row, column=0, sticky="w", padx=(0, 8), pady=(14, 3))
scale_frame = tk.Frame(main)
scale_frame.grid(row=settings_row, column=1, sticky="ew", pady=(14, 3))
scale_slider = tk.Scale(scale_frame, from_=75, to=300, resolution=5, orient="horizontal", variable=scale_value_var, command=update_scale_label, length=360)
scale_slider.pack(side="left")
scale_slider.bind("<Button-1>", slider_touched, add="+")
tk.Label(scale_frame, textvariable=scale_label_var, width=34, anchor="w").pack(side="left", padx=(12, 0))
tk.Checkbutton(main, text="Auto", variable=auto_scale_var, command=auto_scale_changed).grid(row=settings_row, column=2, sticky="w", padx=(8, 0), pady=(14, 3))
register_dirty_widgets(main, "FUSION_WINE_SCALE_PERCENT", settings_row, 3, 4)
update_scale_label()

tk.Label(main, text="Fallback scale %").grid(row=settings_row + 1, column=0, sticky="w", padx=(0, 8), pady=3)
scale_fallback_entry = tk.Entry(main, width=20)
scale_fallback_entry.insert(0, paths["FUSION_WINE_SCALE_FALLBACK_PERCENT"])
scale_fallback_entry.grid(row=settings_row + 1, column=1, sticky="w", pady=3)
scale_fallback_entry.bind("<KeyRelease>", on_value_changed, add="+")
scale_fallback_entry.bind("<FocusOut>", on_value_changed, add="+")
entries["FUSION_WINE_SCALE_FALLBACK_PERCENT"] = scale_fallback_entry
register_dirty_widgets(main, "FUSION_WINE_SCALE_FALLBACK_PERCENT", settings_row + 1, 3, 4)

tk.Label(main, text="Overlay size tolerance %").grid(row=settings_row + 2, column=0, sticky="w", padx=(0, 8), pady=3)
overlay_tolerance_entry = tk.Entry(main, width=20)
overlay_tolerance_entry.insert(0, paths["FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT"])
overlay_tolerance_entry.grid(row=settings_row + 2, column=1, sticky="w", pady=3)
overlay_tolerance_entry.bind("<KeyRelease>", on_value_changed, add="+")
overlay_tolerance_entry.bind("<FocusOut>", on_value_changed, add="+")
entries["FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT"] = overlay_tolerance_entry
register_dirty_widgets(main, "FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT", settings_row + 2, 3, 4)

status_warning_label = tk.Label(main, textvariable=status_warning_var, anchor="w", fg="#b36b00")
status_warning_label.grid(row=settings_row + 3, column=0, columnspan=5, sticky="ew", pady=(10, 0))

main.columnconfigure(1, weight=1)

for key, value in flags.items():
    flag_vars[key] = tk.IntVar(value=1 if as_bool(value) else 0)


def revert_value(key):
    saved_value = saved_values.get(key, "")

    if key == "FUSION_WINE_SCALE_PERCENT":
        if saved_value == "auto":
            auto_scale_var.set(1)
            detected_scale = detected_cinnamon_scale_percent()
            if detected_scale:
                scale_value_var.set(detected_scale)
        else:
            auto_scale_var.set(0)
            if str(saved_value).isdigit():
                scale_value_var.set(int(saved_value))
        update_scale_label()
        update_all_dirty_indicators()
        return

    if key in entries:
        entries[key].delete(0, tk.END)
        entries[key].insert(0, saved_value)
        update_all_dirty_indicators()
        return

    if key in flag_vars:
        flag_vars[key].set(1 if saved_value == "1" else 0)
        update_all_dirty_indicators()
        return


def open_flags_window():
    flags_window = tk.Toplevel(root)
    flags_window.title("Fusion 360 launcher flags")
    flags_window.transient(root)
    flags_window.grab_set()

    frame = tk.Frame(flags_window, padx=14, pady=14)
    frame.pack(fill="both", expand=True)

    tk.Label(frame, text="Simple launch flags", font=("TkDefaultFont", 11, "bold")).grid(row=0, column=0, columnspan=4, sticky="w", pady=(0, 8))
    tk.Label(frame, text="Changed").grid(row=0, column=1, sticky="w", pady=(0, 8))

    for row_index, (label, key) in enumerate(flag_rows, start=1):
        tk.Checkbutton(frame, text=label, variable=flag_vars[key], command=on_value_changed).grid(row=row_index, column=0, sticky="w", pady=2)
        register_dirty_widgets(frame, key, row_index, 1, 2)
        update_dirty_indicator(key)

    buttons = tk.Frame(frame)
    buttons.grid(row=len(flag_rows) + 1, column=0, columnspan=4, sticky="ew", pady=(14, 0))
    tk.Button(buttons, text="OK", command=flags_window.destroy).pack(side="right")

    update_all_dirty_indicators()
    flags_window.wait_window()


def validate_entries():
    scale_fallback = entries["FUSION_WINE_SCALE_FALLBACK_PERCENT"].get().strip()
    overlay_tolerance = entries["FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT"].get().strip()

    if not scale_fallback.isdigit():
        messagebox.showerror("Invalid fallback scale", "Fallback scale must be a number, like 100, 125, 150, or 200.")
        return False

    if not overlay_tolerance.isdigit():
        messagebox.showerror("Invalid overlay tolerance", "Overlay size tolerance must be a number.")
        return False

    return True


def collect_config_values():
    values = {}
    for key, entry in entries.items():
        values[key] = entry.get().strip()

    for key, var in flag_vars.items():
        values[key] = "1" if var.get() else "0"

    values["FUSION_WINE_SCALE_PERCENT"] = "auto" if auto_scale_var.get() else str(scale_value_var.get())
    values["FUSION_WINE_DPI"] = "auto"
    values["FUSION_WINE_DPI_FALLBACK"] = str(percent_to_dpi(values["FUSION_WINE_SCALE_FALLBACK_PERCENT"]))

    return values


def collect_display_values():
    values = collect_config_values()
    return {key: values.get(key, "") for key in displayed_keys() + ["FUSION_WINE_DPI", "FUSION_WINE_DPI_FALLBACK"]}


def write_config_values():
    if not validate_entries():
        return False

    values = collect_config_values()

    os.makedirs(os.path.dirname(config_file), exist_ok=True)

    with open(config_file, "w", encoding="utf-8") as config:
        for key in CONFIG_KEYS:
            config.write(f"{key}={shlex.quote(values.get(key, ''))}\n")

    saved_values.update(collect_display_values())
    update_all_dirty_indicators()
    return True


def restart_wine_processes():
    restart_script = collect_config_values().get("FUSION_WINE_RESTART_SCRIPT", "").strip()

    if not restart_script:
        messagebox.showerror("Restart script missing", "No Wine restart script is configured.")
        return False

    if not os.path.isfile(restart_script):
        messagebox.showerror("Restart script missing", f"Wine restart script was not found:\n\n{restart_script}")
        return False

    result = subprocess.run(["bash", restart_script], check=False)

    if result.returncode != 0:
        messagebox.showerror(
            "Wine restart failed",
            f"Wine restart script exited with status {result.returncode}:\n\n{restart_script}",
        )
        return False

    return True


def ask_save_restart_cancel(changed_keys):
    dialog = tk.Toplevel(root)
    dialog.title("Wine restart needed")
    dialog.transient(root)
    dialog.grab_set()
    dialog.resizable(False, False)

    result = tk.StringVar(value="cancel")

    frame = tk.Frame(dialog, padx=16, pady=14)
    frame.pack(fill="both", expand=True)

    tk.Label(frame, text="⚠ Wine restart needed", font=("TkDefaultFont", 11, "bold"), fg="#b36b00").pack(anchor="w")
    tk.Label(
        frame,
        text="Some modified settings are only reliable after running the configured Wine restart script.",
        justify="left",
        wraplength=560,
    ).pack(anchor="w", pady=(8, 0))

    if changed_keys:
        tk.Label(frame, text="Modified restart-related items:", justify="left").pack(anchor="w", pady=(10, 0))
        list_text = "\n".join(f"- {key}" for key in changed_keys[:12])
        if len(changed_keys) > 12:
            list_text += f"\n- ... {len(changed_keys) - 12} more"
        tk.Label(frame, text=list_text, justify="left", fg="#555555").pack(anchor="w", padx=(12, 0), pady=(2, 0))

    button_frame = tk.Frame(frame)
    button_frame.pack(fill="x", pady=(16, 0))

    def choose(value):
        result.set(value)
        dialog.destroy()

    tk.Button(button_frame, text="Cancel", command=lambda: choose("cancel")).pack(side="right", padx=(8, 0))
    tk.Button(button_frame, text="Save and restart Wine", command=lambda: choose("restart")).pack(side="right", padx=(8, 0))
    tk.Button(button_frame, text="Save", command=lambda: choose("save")).pack(side="right")

    dialog.protocol("WM_DELETE_WINDOW", lambda: choose("cancel"))
    dialog.wait_window()
    return result.get()


def save_with_optional_restart(show_saved_message=True):
    changed_restart_keys = restart_dirty_keys()

    if changed_restart_keys:
        action = ask_save_restart_cancel(changed_restart_keys)
        if action == "cancel":
            return False

        if not write_config_values():
            return False

        if action == "restart":
            if not restart_wine_processes():
                return False
            if show_saved_message:
                messagebox.showinfo("Saved", "Fusion launcher config saved. Wine restart script was run.")
        elif show_saved_message:
            messagebox.showinfo("Saved", "Fusion launcher config saved. Wine was not restarted.")

        return True

    if not write_config_values():
        return False

    if show_saved_message:
        messagebox.showinfo("Saved", "Fusion launcher config saved.")

    return True


def save_config_only():
    stop_countdown()
    save_with_optional_restart(show_saved_message=True)


def continue_launch():
    stop_countdown()
    if save_with_optional_restart(show_saved_message=False):
        root.destroy()


def cancel():
    root.destroy()
    sys.exit(1)

countdown_seconds = 5
countdown_remaining = countdown_seconds
countdown_active = ui_mode == "countdown"
countdown_job = None
focus_pause_enabled = False
countdown_label_var = tk.StringVar()


def stop_countdown(_event=None):
    global countdown_active
    global countdown_job

    if not countdown_active:
        return

    countdown_active = False

    if countdown_job is not None:
        try:
            root.after_cancel(countdown_job)
        except tk.TclError:
            pass

    countdown_label_var.set("Launch paused. Click Continue when ready.")


def stop_countdown_from_focus(_event=None):
    if focus_pause_enabled:
        stop_countdown()


def enable_focus_pause():
    global focus_pause_enabled
    focus_pause_enabled = True


def countdown_tick():
    global countdown_remaining
    global countdown_job

    if not countdown_active:
        return

    if countdown_remaining <= 0:
        continue_launch()
        return

    countdown_label_var.set(f"Launching Fusion in {countdown_remaining} seconds. Click this window to pause.")
    countdown_remaining -= 1
    countdown_job = root.after(1000, countdown_tick)


def open_flags_window_and_pause():
    stop_countdown()
    open_flags_window()

buttons = tk.Frame(main)
buttons.grid(row=settings_row + 4, column=0, columnspan=5, sticky="ew", pady=(16, 0))

countdown_label = tk.Label(buttons, textvariable=countdown_label_var, anchor="w")
countdown_label.pack(side="left", padx=(0, 12))

tk.Button(buttons, text="Flags...", command=open_flags_window_and_pause).pack(side="left")
tk.Button(buttons, text="Cancel", command=cancel).pack(side="right", padx=(8, 0))
tk.Button(buttons, text="Continue", command=continue_launch).pack(side="right", padx=(8, 0))
tk.Button(buttons, text="Save", command=save_config_only).pack(side="right")

root.bind_all("<ButtonPress>", stop_countdown, add="+")
root.bind_all("<KeyPress>", stop_countdown, add="+")
root.bind("<FocusIn>", stop_countdown_from_focus, add="+")
root.after(800, enable_focus_pause)

update_all_dirty_indicators()

if countdown_active:
    countdown_tick()
else:
    countdown_label_var.set("Review settings, then click Continue.")
root.protocol("WM_DELETE_WINDOW", cancel)
root.mainloop()

PY_CONFIG_UI
  local config_ui_status=$?
  [[ $config_ui_status -eq 0 ]] || return "$config_ui_status"

  load_config
}

show_selection_summary() {
  cat <<EOF_SUMMARY
Fusion 360 launch selections:
  Proton executable: $PROTON
  Proton prefix: $STEAM_COMPAT_DATA_PATH
  Steam install directory: $STEAM_COMPAT_CLIENT_INSTALL_PATH
  Fusion production directory: $FUSION_ROOT
  Browser bridge script: $BROWSER
  Browser listener script: $BROWSER_LISTENER
  Callback handler script: $CALLBACK_HANDLER
  Chrome executable: $CHROME
  Wine scale percent: $FUSION_WINE_SCALE_PERCENT
  Wine scale fallback percent: $FUSION_WINE_SCALE_FALLBACK_PERCENT
  Wine DPI legacy value: $FUSION_WINE_DPI
  Wine DPI fallback: $FUSION_WINE_DPI_FALLBACK
  Grey overlay killer: $FUSION_OVERLAY_KILLER
  Grey overlay killer enabled: $FUSION_ENABLE_OVERLAY_KILLER
  Wine restart script: $FUSION_WINE_RESTART_SCRIPT
EOF_SUMMARY
}

clear_bridge_temp_files() {
  mkdir -p "$BRIDGE_BROWSER_REQUEST_DIR"
  mkdir -p "$BRIDGE_BROWSER_PROCESSED_DIR"
  mkdir -p "$BRIDGE_CALLBACK_REQUEST_DIR"
  mkdir -p "$BRIDGE_CALLBACK_PROCESSED_DIR"

  find "$BRIDGE_BROWSER_REQUEST_DIR" -type f \( -name "*.request" -o -name "*.partial" \) -delete 2>/dev/null || true
  find "$BRIDGE_BROWSER_PROCESSED_DIR" -type f \( -name "*.request" -o -name "*.partial" \) -delete 2>/dev/null || true
  find "$BRIDGE_CALLBACK_REQUEST_DIR" -type f \( -name "*.request" -o -name "*.partial" \) -delete 2>/dev/null || true
  find "$BRIDGE_CALLBACK_PROCESSED_DIR" -type f \( -name "*.request" -o -name "*.partial" \) -delete 2>/dev/null || true
}

read_gsettings_number() {
  local schema_name="$1"
  local key_name="$2"
  local raw_value

  command -v gsettings >/dev/null 2>&1 || return 1

  raw_value="$(gsettings get "$schema_name" "$key_name" 2>/dev/null)" || return 1
  printf "%s\n" "$raw_value" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -n 1
}

scale_to_dpi() {
  local scale_value="$1"

  awk -v scale_value="$scale_value" 'BEGIN { printf "%d", (96 * scale_value) + 0.5 }'
}

percent_to_dpi() {
  local percent_value="$1"

  awk -v percent_value="$percent_value" 'BEGIN { printf "%d", (96 * percent_value / 100) + 0.5 }'
}

resolve_fusion_wine_dpi() {
  local cinnamon_scaling_factor
  local cinnamon_text_scaling_factor

  if printf "%s\n" "$FUSION_WINE_SCALE_PERCENT" | grep -Eq '^[0-9]+$'; then
    percent_to_dpi "$FUSION_WINE_SCALE_PERCENT"
    return 0
  fi

  if printf "%s\n" "$FUSION_WINE_DPI" | grep -Eq '^[0-9]+$'; then
    printf "%s" "$FUSION_WINE_DPI"
    return 0
  fi

  cinnamon_text_scaling_factor="$(read_gsettings_number org.cinnamon.desktop.interface text-scaling-factor || true)"
  cinnamon_scaling_factor="$(read_gsettings_number org.cinnamon.desktop.interface scaling-factor || true)"

  if [[ -n "$cinnamon_text_scaling_factor" ]]; then
    if awk -v value="$cinnamon_text_scaling_factor" 'BEGIN { exit !(value > 0 && value != 1) }'; then
      scale_to_dpi "$cinnamon_text_scaling_factor"
      return 0
    fi
  fi

  if [[ -n "$cinnamon_scaling_factor" ]]; then
    if awk -v value="$cinnamon_scaling_factor" 'BEGIN { exit !(value > 1) }'; then
      scale_to_dpi "$cinnamon_scaling_factor"
      return 0
    fi
  fi

  if printf "%s\n" "$FUSION_WINE_SCALE_FALLBACK_PERCENT" | grep -Eq '^[0-9]+$'; then
    percent_to_dpi "$FUSION_WINE_SCALE_FALLBACK_PERCENT"
    return 0
  fi

  printf "%s" "$FUSION_WINE_DPI_FALLBACK"
}

apply_fusion_wine_dpi() {
  local dpi_value
  local win8_dpi_scaling

  dpi_value="$(resolve_fusion_wine_dpi)"

  if [[ "$dpi_value" -eq 96 ]]; then
    win8_dpi_scaling=0
  else
    win8_dpi_scaling=1
  fi

  {
    echo "timestamp=$(date -Is)"
    echo "FUSION_WINE_DPI=$FUSION_WINE_DPI"
    echo "FUSION_WINE_SCALE_PERCENT=$FUSION_WINE_SCALE_PERCENT"
    echo "FUSION_WINE_DPI_FALLBACK=$FUSION_WINE_DPI_FALLBACK"
    echo "FUSION_WINE_SCALE_FALLBACK_PERCENT=$FUSION_WINE_SCALE_FALLBACK_PERCENT"
    echo "resolved_dpi=$dpi_value"
    echo "win8_dpi_scaling=$win8_dpi_scaling"
    echo "cinnamon_scaling_factor=$(read_gsettings_number org.cinnamon.desktop.interface scaling-factor || true)"
    echo "cinnamon_text_scaling_factor=$(read_gsettings_number org.cinnamon.desktop.interface text-scaling-factor || true)"
  } > "$FUSION_DPI_LOG_FILE"

  "$PROTON" run reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d "$dpi_value" /f >> "$FUSION_DPI_LOG_FILE" 2>&1 || {
    echo "launch-fusion.sh warning: failed to set Wine Fonts LogPixels. See $FUSION_DPI_LOG_FILE" >&2
  }

  "$PROTON" run reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$dpi_value" /f >> "$FUSION_DPI_LOG_FILE" 2>&1 || {
    echo "launch-fusion.sh warning: failed to set Desktop LogPixels. See $FUSION_DPI_LOG_FILE" >&2
  }

  "$PROTON" run reg add 'HKCU\Control Panel\Desktop' /v Win8DpiScaling /t REG_DWORD /d "$win8_dpi_scaling" /f >> "$FUSION_DPI_LOG_FILE" 2>&1 || {
    echo "launch-fusion.sh warning: failed to set Win8DpiScaling. See $FUSION_DPI_LOG_FILE" >&2
  }

  {
    echo
    echo "---- registry check after write ----"
    "$PROTON" run reg query 'HKCU\Software\Wine\Fonts' /v LogPixels 2>&1 || true
    "$PROTON" run reg query 'HKCU\Control Panel\Desktop' /v LogPixels 2>&1 || true
    "$PROTON" run reg query 'HKCU\Control Panel\Desktop' /v Win8DpiScaling 2>&1 || true
  } >> "$FUSION_DPI_LOG_FILE"
}

install_callback_protocol_handlers() {
  local applications_dir
  local desktop_file

  applications_dir="$HOME/.local/share/applications"
  desktop_file="$applications_dir/fusion360-callback-handler.desktop"

  mkdir -p "$applications_dir"

  cat > "$desktop_file" <<EOF_DESKTOP
[Desktop Entry]
Name=Fusion 360 Autodesk Callback Handler
Exec=$CALLBACK_HANDLER %u
Type=Application
NoDisplay=true
MimeType=x-scheme-handler/adsk;x-scheme-handler/adskidmgr;
EOF_DESKTOP

  xdg-mime default fusion360-callback-handler.desktop x-scheme-handler/adsk 2>/dev/null || true
  xdg-mime default fusion360-callback-handler.desktop x-scheme-handler/adskidmgr 2>/dev/null || true

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
  fi
}

register_wine_browser_bridge() {
  "$PROTON" run reg add 'HKCU\Software\Wine\WineBrowser' /v Browsers /t REG_SZ /d "$BROWSER" /f >/tmp/fusion360-winebrowser-register.log 2>&1 || {
    echo "launch-fusion.sh warning: failed to register WineBrowser. See /tmp/fusion360-winebrowser-register.log" >&2
  }
}

start_browser_listener() {
  [[ -x "$BROWSER_LISTENER" ]] || fail "Browser listener was not found or is not executable: $BROWSER_LISTENER"

  clear_bridge_temp_files

  "$BROWSER_LISTENER" &
  BRIDGE_LISTENER_PID="$!"

  echo "launch-fusion.sh: browser listener started with PID $BRIDGE_LISTENER_PID"
}

start_overlay_killer() {
  is_enabled "$FUSION_ENABLE_OVERLAY_KILLER" || return 0

  if [[ ! -x "$FUSION_OVERLAY_KILLER" ]]; then
    echo "launch-fusion.sh warning: overlay killer is enabled but not executable: $FUSION_OVERLAY_KILLER" >&2
    return 0
  fi

  FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT="$FUSION_OVERLAY_SIZE_TOLERANCE_PERCENT" "$FUSION_OVERLAY_KILLER" &
  OVERLAY_KILLER_PID="$!"

  echo "launch-fusion.sh: overlay killer started with PID $OVERLAY_KILLER_PID"
}

cleanup() {
  if [[ -n "$OVERLAY_KILLER_PID" ]]; then
    if kill -0 "$OVERLAY_KILLER_PID" 2>/dev/null; then
      kill "$OVERLAY_KILLER_PID" 2>/dev/null || true
      wait "$OVERLAY_KILLER_PID" 2>/dev/null || true
    fi
  fi

  if [[ -n "$BRIDGE_LISTENER_PID" ]]; then
    if kill -0 "$BRIDGE_LISTENER_PID" 2>/dev/null; then
      kill "$BRIDGE_LISTENER_PID" 2>/dev/null || true
      wait "$BRIDGE_LISTENER_PID" 2>/dev/null || true
    fi
  fi

  clear_bridge_temp_files
}

apply_launch_environment() {
  export PROTON_USE_WINED3D="$FUSION_PROTON_USE_WINED3D"
  export PROTON_USE_XALIA="$FUSION_PROTON_USE_XALIA"

  if is_enabled "$FUSION_DXVK_ASYNC"; then
    export DXVK_ASYNC=1
  else
    unset DXVK_ASYNC
  fi

  if is_enabled "$FUSION_NO_AT_BRIDGE"; then
    export NO_AT_BRIDGE=1
  else
    unset NO_AT_BRIDGE
  fi

  if is_enabled "$FUSION_FIX_BCP47LANGS"; then
    export WINEDLLOVERRIDES="bcp47langs="
  else
    unset WINEDLLOVERRIDES
  fi

  local webview_arguments=()
  if is_enabled "$FUSION_WEBVIEW_NO_SANDBOX"; then
    webview_arguments+=("--no-sandbox")
  fi
  if is_enabled "$FUSION_WEBVIEW_DISABLE_GPU"; then
    webview_arguments+=("--disable-gpu")
    webview_arguments+=("--disable-features=VizDisplayCompositor")
  fi

  if [[ ${#webview_arguments[@]} -gt 0 ]]; then
    export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="${webview_arguments[*]}"
  else
    unset WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
  fi

  if is_enabled "$FUSION_USE_INTEL_VK_ICD"; then
    if [[ -f /usr/share/vulkan/icd.d/intel_icd.x86_64.json && -f /usr/share/vulkan/icd.d/intel_icd.i686.json ]]; then
      export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/intel_icd.x86_64.json:/usr/share/vulkan/icd.d/intel_icd.i686.json"
    else
      echo "launch-fusion.sh warning: Intel Vulkan ICD flag is enabled, but one of the Intel ICD files was not found." >&2
    fi
  fi

  export BROWSER
  export BROWSER_LISTENER
  export CALLBACK_HANDLER
  export CHROME
  export FUSION_WINE_DPI
  export FUSION_WINE_SCALE_PERCENT
  export FUSION_WINE_DPI_FALLBACK
  export FUSION_WINE_SCALE_FALLBACK_PERCENT
  export STEAM_COMPAT_DATA_PATH
  export STEAM_COMPAT_CLIENT_INSTALL_PATH
}

load_config

if [[ "${1:-}" == "--configure" ]]; then
  configure_with_file_browsers hold || exit 1
  exit 0
fi

missing_selection=0
[[ -x "$PROTON" ]] || missing_selection=1
[[ -x "$BROWSER" ]] || missing_selection=1
[[ -x "$BROWSER_LISTENER" ]] || missing_selection=1
[[ -x "$CALLBACK_HANDLER" ]] || missing_selection=1
[[ -x "$CHROME" ]] || missing_selection=1
[[ -d "$FUSION_ROOT" ]] || missing_selection=1
if is_enabled "$FUSION_ENABLE_OVERLAY_KILLER"; then
  [[ -x "$FUSION_OVERLAY_KILLER" ]] || missing_selection=1
fi

if [[ -n "${DISPLAY:-}" && -z "${FUSION_SKIP_UI:-}" ]]; then
  if [[ $missing_selection -eq 1 ]]; then
    configure_with_file_browsers hold || exit 1
  else
    configure_with_file_browsers countdown || exit 1
  fi
fi

apply_launch_environment

[[ -x "$PROTON" ]] || fail "Proton was not found or is not executable: $PROTON. Run $0 --configure to select it."
[[ -x "$BROWSER" ]] || fail "Browser bridge was not found or is not executable: $BROWSER. Run $0 --configure to select it."
[[ -x "$BROWSER_LISTENER" ]] || fail "Browser listener was not found or is not executable: $BROWSER_LISTENER"
[[ -x "$CALLBACK_HANDLER" ]] || fail "Callback handler was not found or is not executable: $CALLBACK_HANDLER"
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

trap cleanup EXIT INT TERM

apply_fusion_wine_dpi
install_callback_protocol_handlers
register_wine_browser_bridge
start_browser_listener
start_overlay_killer

"$PROTON" run "$FUSION_EXE" "$@"
fusion_status=$?

[[ $fusion_status -eq 0 ]] || fail "Fusion exited or crashed with status $fusion_status"
exit 0