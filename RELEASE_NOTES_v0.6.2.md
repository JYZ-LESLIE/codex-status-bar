# v0.6.2 - Dismiss Opened Cards

Small task-board behavior fix.

## Changed

- Clicking a task card now opens the Codex thread and immediately marks that card as read.
- Read cards are stored in `~/Library/Application Support/CodexStatusBar/dismissed.json`.
- The hidden key is `session_id + event_id`, so the same thread reappears when a new event arrives.
- The `打开当前线程` menu action uses the same read-and-hide behavior.

## Why

The status bar should behave like an inbox. Once a card has been opened, it should not keep occupying attention space until there is new activity.
