# Codex Status Bar v0.2.0

Full-shape release for MacBook notch displays and external monitors.

## What changed

- Added a top-center island overlay on the active screen.
- Kept the menu bar item as the always-visible external-monitor fallback.
- Added clear state markers:
  - `RUNNING`
  - `DONE`
  - `NEEDS FEEDBACK`
- Added notification handling for feedback-needed events.
- Expanded Codex hook installation to include `PreToolUse`, `PostToolUse`, and `Notification`, while still staying fail-open.

## Why

The first release solved external-monitor visibility with a menu bar item and notifications. This release adds the complete shape: a lightweight island for MacBook/notch-style use, plus menu bar and notification fallback for external displays.

## Open source thanks

Thanks again to Vibe Island for the ambient control-surface idea, and to `Octane0411/open-vibe-island`, `wxtsky/CodeIsland`, and related community projects for exploring agent status surfaces and Codex hook workflows.

No source code from those projects is vendored in this release.
