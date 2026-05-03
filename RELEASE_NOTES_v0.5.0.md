# v0.5.0 - Color Task Triage

This release makes the menu bar useful before opening Codex.

## Changed

- Added task triage fields: `task_type`, `task_label`, `task_color`, and `status_color`.
- The menu bar title now starts with a colored status dot.
- Session rows now use colored dots and task labels, such as `写代码`, `测试`, `发布`, `查看`, `要反馈`, and `完成`.
- Session rows are clickable when a Codex session id is available, so the menu works as a triage board first and an entry point second.
- Added a color legend inside the menu.
- The top island includes the task label in alert copy.

## Color Logic

- Orange-red: user confirmation or feedback needed.
- Blue: code writing or active processing.
- Teal: tests or builds.
- Purple: GitHub release and publishing.
- Green: completed.
- Slate gray: reading, inspection, or research.

## Why

Opening the menu should answer a different question than opening Codex: which thread matters, what kind of task it is, and whether it needs action now.
