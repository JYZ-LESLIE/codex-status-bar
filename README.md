# Codex Status Bar

Codex Status Bar is a tiny macOS menu bar notifier for Codex. It is built for people who work on external monitors and cannot rely on a MacBook notch or Dynamic Island style overlay.

It listens to Codex hook events, writes a local event log, shows the latest Codex state in the menu bar, and sends macOS notifications when a prompt is submitted or a turn completes.

## Why this exists

Vibe Island and Open Island showed that AI coding agents need a lightweight ambient control surface. In my own workflow, the missing case was external-monitor work: the notch is often not visible, and full historical session scanning can be expensive when Codex has very large rollout files.

This project focuses on that narrower problem:

- menu bar first, so it works on external displays
- notifications for prompt and completion events
- no historical rollout scan
- fail-open hook behavior, so Codex keeps working if the status app is not running

## Install

```bash
./install.sh
```

The installer builds a small native macOS app, installs the hook sink, updates `~/.codex/hooks.json`, and adds a LaunchAgent so the app starts at login.

## Uninstall

```bash
./uninstall.sh
```

The event history is preserved under `~/Library/Application Support/CodexStatusBar/`.

## What changed versus the inspiration

This is not a clone of Vibe Island or Open Island. It borrows the product insight that coding agents need ambient status, but changes the implementation surface:

- replaces notch-first UI with a menu bar item
- keeps the event source to current Codex hooks only
- avoids scanning `~/.codex/sessions/**/rollout-*.jsonl`
- adds a simple local JSONL event log
- keeps the hook sink independent of the running app

## Open source thanks

Thanks to:

- [Vibe Island](https://vibeisland.app/) for proving the ambient AI-agent control surface.
- [Octane0411/open-vibe-island](https://github.com/Octane0411/open-vibe-island) for the open-source reference and for documenting Codex hook integration patterns.
- [wxtsky/CodeIsland](https://github.com/wxtsky/CodeIsland) and other community projects that explored agent status surfaces on macOS.

No source code from those projects is vendored here. This repository is a small independent menu bar implementation for the external-monitor use case.

## Files

- `CodexStatusBar.swift`: native AppKit menu bar app.
- `codex_status_hook.py`: fail-open Codex hook sink.
- `scripts/install_codex_hooks.py`: updates `~/.codex/hooks.json`.
- `scripts/uninstall_codex_hooks.py`: removes the Codex Status Bar hook entries.

## License

MIT.
