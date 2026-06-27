# Fusion 360 on Linux via Proton

Small helper scripts for running Autodesk Fusion 360 on Linux with GE-Proton.

This is not an official Autodesk setup. It is a pragmatic wrapper around a Proton prefix that already contains Fusion 360.

## Installation

The shortest working path is to keep the same directory layout used by the scripts. You can also run the assistant to select your Proton, Fusion, Steam, browser, and WebView2 settings instead of editing scripts.

### 1. Put this repo in place

```bash
cd ~
# clone or copy this directory as ~/fusion
cd ~/fusion
chmod +x launch-fusion.sh fusion-browser.sh
```

The Makefile expects this repository to be run from `~/fusion`.

### 2. Install GE-Proton

Download `GE-Proton10-32.tar.gz` from the Proton-GE releases page, then extract it into Steam compatibility tools:

```bash
mkdir -p ~/.local/share/Steam/compatibilitytools.d
tar -xf ~/Downloads/fusion360-linux-install/GE-Proton10-32.tar.gz \
  -C ~/.local/share/Steam/compatibilitytools.d
```

After extraction, this file should exist:

```text
~/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton
```

### 3. Download the Fusion installer

Put Autodesk's `FusionClientDownloader.exe` here:

```text
~/Downloads/fusion360-linux-install/FusionClientDownloader.exe
```

### 4. Install Fusion 360 into the Proton prefix

```bash
export STEAM_COMPAT_DATA_PATH="$HOME/.fusion360-proton2"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"

"$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton" run \
  "$HOME/Downloads/fusion360-linux-install/FusionClientDownloader.exe"
```

When the installer finishes, `Fusion360.exe` should appear under:

```text
~/.fusion360-proton2/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production/
```

`launch-fusion.sh` finds the current `Fusion360.exe` automatically.

### 5. Run Fusion 360

```bash
cd ~/fusion
make run
```

To choose the directories and executables with a small UI, run:

```bash
make assistant
```

The assistant uses `zenity` when available, `kdialog` when available, and terminal prompts otherwise. It writes settings to:

```text
~/.config/fusion360-linux/settings
```

Check whether it is running:

```bash
make ps
```

Stop it:

```bash
make kill
```

## Sign In

If clicking `Sign in` does not open Chrome, check the browser log:

```bash
tail -n 20 /tmp/fusion-browser.log
```

Copy the latest Autodesk sign-in URL into Chrome manually. Do not share this URL; it can contain authentication state.

`fusion-browser.sh` uses `/usr/bin/google-chrome` by default. If your Chrome binary is elsewhere, run `make assistant` and select the browser executable.

## Notes

`launch-fusion.sh` copies Fusion's production config to `Fusion 360.server.config` on every launch. This avoids the staging config error that tries to reach `art-bobcat.autodesk.com`.

Current WebView2 option:

```bash
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox"
```

If the sign-in window becomes black, try the fallback in `launch-fusion.sh`:

```bash
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--disable-gpu --no-sandbox"
```

Then restart Fusion:

```bash
make kill
make run
```
