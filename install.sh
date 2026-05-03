#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications/Codex Status Bar.app"
APP_SUPPORT="$HOME/Library/Application Support/CodexStatusBar"
HOOK_PATH="$APP_SUPPORT/bin/codex_status_hook.py"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.jiyuanzheng.codex-status-bar.plist"
CONFIG_DIR="$HOME/.codex"
HOOKS_JSON="$CONFIG_DIR/hooks.json"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_SUPPORT/bin" "$HOME/Library/LaunchAgents" "$CONFIG_DIR"

pkill -f "Codex Status Bar.app/Contents/MacOS/CodexStatusBar" 2>/dev/null || true

swiftc -O -framework AppKit -framework UserNotifications \
  "$ROOT/CodexStatusBar.swift" \
  -o "$APP_DIR/Contents/MacOS/CodexStatusBar"

cp "$ROOT/codex_status_hook.py" "$HOOK_PATH"
chmod +x "$HOOK_PATH"

/usr/bin/plutil -create xml1 "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleDevelopmentRegion -string en "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleExecutable -string CodexStatusBar "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.jiyuanzheng.codex-status-bar "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleName -string "Codex Status Bar" "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleDisplayName -string "Codex Status Bar" "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundlePackageType -string APPL "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleShortVersionString -string 0.6.2 "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleVersion -string 8 "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert LSUIElement -bool true "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert NSUserNotificationAlertStyle -string banner "$APP_DIR/Contents/Info.plist"

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

python3 "$ROOT/scripts/install_codex_hooks.py" "$HOOK_PATH"

/usr/bin/plutil -create xml1 "$LAUNCH_AGENT"
/usr/bin/plutil -insert Label -string com.jiyuanzheng.codex-status-bar "$LAUNCH_AGENT"
/usr/bin/plutil -insert ProgramArguments -array "$LAUNCH_AGENT"
/usr/bin/plutil -insert ProgramArguments.0 -string /usr/bin/open "$LAUNCH_AGENT"
/usr/bin/plutil -insert ProgramArguments.1 -string -g "$LAUNCH_AGENT"
/usr/bin/plutil -insert ProgramArguments.2 -string "$APP_DIR" "$LAUNCH_AGENT"
/usr/bin/plutil -insert RunAtLoad -bool true "$LAUNCH_AGENT"
/usr/bin/plutil -insert KeepAlive -bool false "$LAUNCH_AGENT"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
launchctl kickstart -k "gui/$(id -u)/com.jiyuanzheng.codex-status-bar"

echo "Installed Codex Status Bar."
echo "Menu bar app: $APP_DIR"
echo "Hook: $HOOK_PATH"
