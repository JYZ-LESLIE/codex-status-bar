# v0.4.0 - Quiet Progress, Clear Feedback

This release tightens the product contract for people who run multiple Codex conversations at once.

## Changed

- Running work is quiet now: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, and `PostToolUse` update the menu bar state without sending a notification or showing the top island.
- Only `Stop`, `Notification`, and compatible feedback events are treated as alert-worthy.
- Added a local multi-session progress ledger at `~/Library/Application Support/CodexStatusBar/sessions.json`.
- Events now include `kind`, `phase`, `requires_user`, and `priority` so progress and attention are not mixed.
- The menu now groups sessions into `需要你看`, `运行中`, and `最近完成`.
- Notification and top-island copy now includes the project/workspace name, so it is clearer which Codex conversation needs attention.
- If a session is already waiting for user input, ordinary running/progress events no longer downgrade it in the session list.
- Hook payload logging now trims large tool responses, so normal tool output does not bloat the local event log.

## Why

The app should not interrupt while Codex is writing code. It should stay visible enough for external-monitor work, but only actively interrupt when a thread has stopped or needs the user to do the next step.
