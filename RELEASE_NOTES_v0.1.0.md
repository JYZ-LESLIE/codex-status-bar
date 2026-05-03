# Codex Status Bar v0.1.0

Initial public release.

## What it does

- Adds a native macOS menu bar status item for Codex activity.
- Sends notifications when Codex receives a prompt or completes a turn.
- Stores the latest state and a local JSONL event log under `~/Library/Application Support/CodexStatusBar/`.
- Installs and removes Codex hook entries with simple shell scripts.
- Avoids scanning historical Codex rollout files, which keeps it light for machines with large Codex histories.

## What changed from the inspiration

This is an external-monitor-first companion, not a notch-first Dynamic Island clone:

- menu bar first instead of notch overlay first
- current Codex hook events only instead of historical rollout recovery
- fail-open hook sink that never blocks Codex
- lightweight local event log for debugging

## Open source thanks

Thanks to Vibe Island for proving the ambient AI-agent control-surface idea, and to `Octane0411/open-vibe-island`, `wxtsky/CodeIsland`, and related community projects for documenting and exploring Codex/agent status workflows.

No source code from those projects is vendored in this release.
