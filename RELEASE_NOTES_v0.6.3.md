# Codex Status Bar v0.6.3

## What changed

- Added auto-read cleanup for completed cards when Codex is opened directly from another window/surface.
- Cleared stale completion or feedback cards when the same thread receives new user input or continues tool work.
- Stopped treating a new thread start or empty stop as a completed task.
- Added `show_in_board`, `had_user_prompt`, and `had_tool_activity` session fields so completion reminders mean phase closeout, not raw hook shutdown.
- Added a two-hour natural expiry for completed cards; running projects keep the existing menu logic.
- Cleaned JSON-style thread titles such as `{"title":"..."}` before rendering.
- Filtered legacy stop-only cards from older versions when they carry JSON/raw-message titles.

## Validation

- `python3 -m py_compile codex_status_hook.py`
- `swiftc -O -framework AppKit -framework UserNotifications CodexStatusBar.swift -o /tmp/CodexStatusBar-test`
- Hook fixture checks for hidden SessionStart, hidden stop-only completion, visible phase completion, feedback cleared by user input, and JSON-title cleanup.
