# Fusion 360 on Linux via Proton

Small helper scripts for running Autodesk Fusion 360 on Linux with Proton or GE-Proton.

This is not an official Autodesk setup. It is a pragmatic wrapper around a Proton prefix that already contains Fusion 360 or that is used to install Fusion 360.

## What this repo does

The launcher handles three separate jobs:

1. Start Fusion 360 through Proton.
2. Bridge the Fusion sign-in request from Wine/Proton to your normal Linux browser.
3. Bridge the Autodesk browser callback back into the Proton Identity Manager.

The sign-in bridge is intentionally split into small scripts because Linux browsers can fail when launched directly from the Wine/Proton process context.

```text
Fusion / Wine
  -> fusion-browser.sh
  -> /tmp/fusion360-browser-requests
  -> fusion-browser-listener.sh
  -> xdg-open Autodesk login URL
  -> browser login
  -> xdg protocol handler
  -> fusion-callback-handler.sh
  -> /tmp/fusion360-callback-requests
  -> fusion-browser-listener.sh
  -> Proton runs AdskIdentityManager.exe with callback URL
  -> Fusion receives sign-in
```

No passwords are written to files. The bridge writes short-lived Autodesk URLs and callback URLs only.

## Files

```text
launch-fusion.sh
  Main launcher. Loads config, starts the bridge listener, registers protocol handlers,
  registers WineBrowser, launches Fusion, then cleans bridge temp files on exit.

fusion-browser.sh
  Called by Fusion/Wine when Autodesk Identity Manager wants to open a browser.
  Writes the requested URL to /tmp/fusion360-browser-requests.

fusion-browser-listener.sh
  Started by launch-fusion.sh from the normal Linux desktop context.
  Opens browser request URLs with xdg-open.
  Sends callback URLs back to AdskIdentityManager.exe through Proton.

fusion-callback-handler.sh
  Called by the Linux desktop xdg protocol handler when the browser opens adsk://
  or adskidmgr:// callback URLs.
  Writes callback requests to /tmp/fusion360-callback-requests.
```

## Installation

The shortest working path is to keep the same directory layout used by the scripts.

### 1. Put this repo in place

```bash
cd ~
# clone or copy this directory as ~/fusion
cd ~/fusion
chmod +x launch-fusion.sh fusion-browser.sh fusion-browser-listener.sh fusion-callback-handler.sh
```

The Makefile expects this repository to be run from `~/fusion`.

### 2. Install Proton or GE-Proton

For GE-Proton, download the release archive, then extract it into Steam compatibility tools:

```bash
mkdir -p ~/.local/share/Steam/compatibilitytools.d
tar -xf ~/Downloads/fusion360-linux-install/GE-Proton10-32.tar.gz \
  -C ~/.local/share/Steam/compatibilitytools.d
```

After extraction, this file would exist for GE-Proton:

```text
~/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton
```

Steam's bundled Proton can also work. Example:

```text
~/.local/share/Steam/steamapps/common/Proton 10.0/proton
```

### 3. Download the Fusion installer

Put Autodesk's `FusionClientDownloader.exe` here:

```text
~/Downloads/fusion360-linux-install/FusionClientDownloader.exe
```

### 4. Install Fusion 360 into a Proton prefix

A dedicated clean prefix can be used:

```bash
export STEAM_COMPAT_DATA_PATH="$HOME/.fusion360-proton2"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"

"$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton" run \
  "$HOME/Downloads/fusion360-linux-install/FusionClientDownloader.exe"
```

When the installer finishes, `Fusion360.exe` is usually under one of these folders:

```text
~/.fusion360-proton2/pfx/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production/
~/.fusion360-proton2/pfx/drive_c/users/<linux-user>/AppData/Local/Autodesk/webdeploy/production/
~/.fusion360-proton2/pfx/drive_c/Program Files/Autodesk/webdeploy/production/
```

`launch-fusion.sh` finds the current `Fusion360.exe` automatically inside the configured Fusion production directory.

## Important path meanings

### Proton executable

This is the actual Proton script:

```text
/path/to/Proton 10.0/proton
/path/to/GE-Proton*/proton
```

Example:

```text
/home/nicolassicard/.local/share/Steam/steamapps/common/Proton 10.0/proton
```

### Proton prefix directory

This is the `STEAM_COMPAT_DATA_PATH`.

Select the directory that contains `pfx`, not `pfx` itself.

Correct:

```text
/home/nicolassicard/.fusion360-proton2
/home/nicolassicard/.local/share/Steam/steamapps/compatdata/2694490
```

Not:

```text
/home/nicolassicard/.fusion360-proton2/pfx
/home/nicolassicard/.local/share/Steam/steamapps/compatdata
```

### Steam install directory

This is the root Steam install directory:

```text
/home/nicolassicard/.local/share/Steam
```

### Fusion production directory

Select the `production` directory, not the hash folder below it.

Correct:

```text
.../Autodesk/webdeploy/production
```

Not:

```text
.../Autodesk/webdeploy/production/<hash>
```

The launcher searches inside `production` for `Fusion360.exe`.

## Configure paths

If Proton, Steam, Fusion, browser bridge, or browser locations differ from the defaults, run:

```bash
./launch-fusion.sh --configure
```

The setup uses `zenity` file browser dialogs and labels each selection:

- Proton executable
- Proton prefix directory
- Steam install directory
- Fusion production directory
- Browser bridge script
- Chrome executable

Selections are saved in:

```text
~/.config/fusion360-linux/config
```

Normal launches do not clear this config file.

You can still override selections for one launch with environment variables:

```text
PROTON
STEAM_COMPAT_DATA_PATH
STEAM_COMPAT_CLIENT_INSTALL_PATH
FUSION_ROOT
BROWSER
CHROME
```

`BROWSER_LISTENER` and `CALLBACK_HANDLER` default to scripts next to `launch-fusion.sh`.

## Run Fusion 360

```bash
cd ~/fusion
make run
```

Check whether it is running:

```bash
make ps
```

Stop it:

```bash
make kill
```

You can also run the launcher directly:

```bash
./launch-fusion.sh
```

## Sign in bridge

On launch, `launch-fusion.sh` does these bridge setup steps:

```text
1. Clear old bridge request files.
2. Register WineBrowser so Fusion calls fusion-browser.sh.
3. Register Linux xdg handlers for adsk:// and adskidmgr://.
4. Start fusion-browser-listener.sh.
5. Launch Fusion through Proton.
6. Stop the listener and clear bridge request files when Fusion exits.
```

The callback protocol handler is written to:

```text
~/.local/share/applications/fusion360-callback-handler.desktop
```

The registered protocols are:

```text
x-scheme-handler/adsk
x-scheme-handler/adskidmgr
```

Check them with:

```bash
xdg-mime query default x-scheme-handler/adsk
xdg-mime query default x-scheme-handler/adskidmgr
```

Expected:

```text
fusion360-callback-handler.desktop
fusion360-callback-handler.desktop
```

## Bridge temp files

The bridge uses these temporary folders:

```text
/tmp/fusion360-browser-requests
/tmp/fusion360-browser-processed
/tmp/fusion360-callback-requests
/tmp/fusion360-callback-processed
```

`launch-fusion.sh` clears only `*.request` and `*.partial` files in those folders at startup and exit.

It does not delete or rewrite:

```text
~/.config/fusion360-linux/config
```

## Logs

Browser request writer:

```bash
cat /tmp/fusion-browser-bridge.log
```

Linux-side listener:

```bash
cat /tmp/fusion-browser-listener.log
```

Callback protocol handler:

```bash
cat /tmp/fusion-callback-handler.log
```

WineBrowser registration:

```bash
cat /tmp/fusion360-winebrowser-register.log
```

If sign-in does not open the browser, check that `fusion-browser.sh` wrote a request and that the listener processed it.

If the browser opens but Fusion does not receive the login, check that the callback handler received an `adsk://` or `adskidmgr://` URL and that the listener sent it to `AdskIdentityManager.exe`.

Do not share the URLs in these logs. They can contain short-lived authentication state.

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

## Working setup backup

After a successful login, make a backup of the working scripts and config:

```bash
cd ~/fusion

mkdir -p working-login-bridge-backup

cp launch-fusion.sh working-login-bridge-backup/
cp fusion-browser.sh working-login-bridge-backup/
cp fusion-browser-listener.sh working-login-bridge-backup/
cp fusion-callback-handler.sh working-login-bridge-backup/
cp ~/.config/fusion360-linux/config working-login-bridge-backup/config

tar -czf fusion360-linux-working-login-bridge.tar.gz working-login-bridge-backup
```
