# v0.6.0 - Task Cards, Not Logs

This release changes the menu from a log list into a compact task board.

## Changed

- Replaced long one-line session rows with two-line card views.
- The first line now prioritizes the Codex thread title, such as `关闭 API 和服务`.
- The second line shows the latest readable progress summary.
- Internal `screen_recording` and `Memory summary` events are hidden from the task board.
- Added display fields in the hook output: `display_title`, `display_subtitle`, and `is_internal`.
- Existing sessions can recover thread titles from bounded reads of Codex transcript files when available.
- The menu top no longer repeats raw workspace and progress strings.

## Why

The menu should not duplicate the Codex sidebar. It should answer the glanceable question: which task is this, what happened, and does it need attention?
