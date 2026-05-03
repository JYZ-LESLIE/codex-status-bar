#!/usr/bin/env python3
"""Codex hook sink for Codex Status Bar.

The hook is fail-open by design: parsing or filesystem errors are logged, but
never block Codex.
"""

from __future__ import annotations

import json
import os
import sys
import time
import traceback
import uuid
from pathlib import Path


APP_DIR = Path.home() / "Library" / "Application Support" / "CodexStatusBar"
LATEST_PATH = APP_DIR / "latest.json"
EVENTS_PATH = APP_DIR / "events.jsonl"
LOG_PATH = APP_DIR / "hook-errors.log"


def _workspace_name(cwd: str | None) -> str:
    if not cwd:
        return "Workspace"
    name = Path(cwd).name
    return name or "Workspace"


def _summary(payload: dict) -> tuple[str, str]:
    event = str(payload.get("hook_event_name") or payload.get("event") or "Codex")
    cwd = str(payload.get("cwd") or "")
    workspace = _workspace_name(cwd)

    prompt = payload.get("prompt")
    assistant = payload.get("last_assistant_message")
    tool = payload.get("tool_name")

    if event == "SessionStart":
        return "Codex running", f"Started in {workspace}"
    if event == "UserPromptSubmit":
        text = str(prompt or "New prompt received").strip()
        return "Codex prompt", text[:160]
    if event == "Stop":
        text = str(assistant or "Turn completed").strip()
        return "Codex done", text[:160]
    if event == "PreToolUse":
        return "Codex working", f"Using {tool or 'tool'} in {workspace}"
    if event == "PostToolUse":
        return "Codex updated", f"Finished {tool or 'tool'} in {workspace}"

    return "Codex event", f"{event} in {workspace}"


def _write_event(payload: dict) -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)

    now = time.time()
    title, body = _summary(payload)
    cwd = str(payload.get("cwd") or "")
    event = {
        "event_id": f"{int(now * 1000)}-{uuid.uuid4().hex[:10]}",
        "timestamp": now,
        "hook_event_name": payload.get("hook_event_name"),
        "session_id": payload.get("session_id"),
        "turn_id": payload.get("turn_id"),
        "cwd": cwd,
        "workspace": _workspace_name(cwd),
        "model": payload.get("model"),
        "title": title,
        "body": body,
        "raw": payload,
    }

    with EVENTS_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")

    tmp = LATEST_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(event, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, LATEST_PATH)


def main() -> int:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return 0
        payload = json.loads(raw)
        if isinstance(payload, dict):
            _write_event(payload)
    except Exception:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            with LOG_PATH.open("a", encoding="utf-8") as handle:
                handle.write(f"\n--- {time.time()} ---\n")
                handle.write(traceback.format_exc())
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
