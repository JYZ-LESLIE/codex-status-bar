#!/usr/bin/env bash
set -euo pipefail

LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.jiyuanzheng.codex-status-bar.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
pkill -f "Codex Status Bar.app/Contents/MacOS/CodexStatusBar" 2>/dev/null || true

python3 "$(cd "$(dirname "$0")" && pwd)/scripts/uninstall_codex_hooks.py"

rm -f "$LAUNCH_AGENT"
rm -rf "$HOME/Applications/Codex Status Bar.app"

echo "Uninstalled Codex Status Bar app and Codex hooks."
echo "Event history is preserved at ~/Library/Application Support/CodexStatusBar/."
