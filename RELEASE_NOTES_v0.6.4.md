# Codex Status Bar v0.6.4

## What changed

- Restored the completed-task section as a first-class board area.
- Removed the overly broad "Codex app activated means all completed cards are read" behavior from v0.6.3.
- Added an explicit `暂无阶段完成` row when there are no visible completed phase cards.
- Kept the intended cleanup behavior: clicking a specific completed card hides that card, and continuing the same thread replaces the old reminder with live progress.

## Validation

- `python3 -m py_compile codex_status_hook.py`
- `swiftc -O -framework AppKit -framework UserNotifications CodexStatusBar.swift -o /tmp/CodexStatusBar-test`

