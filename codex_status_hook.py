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
import fcntl
from pathlib import Path


APP_DIR = Path.home() / "Library" / "Application Support" / "CodexStatusBar"
LATEST_PATH = APP_DIR / "latest.json"
EVENTS_PATH = APP_DIR / "events.jsonl"
SESSIONS_PATH = APP_DIR / "sessions.json"
LOCK_PATH = APP_DIR / ".state.lock"
LOG_PATH = APP_DIR / "hook-errors.log"


def _workspace_name(cwd: str | None) -> str:
    if not cwd:
        return "Workspace"
    name = Path(cwd).name
    return name or "Workspace"


def _clean_text(value: object, fallback: str) -> str:
    text = str(value or fallback).replace("\n", " ").strip()
    return text or fallback


def _truncate(value: object, limit: int = 500) -> object:
    if value is None:
        return None
    text = str(value)
    if len(text) <= limit:
        return value
    return text[:limit] + f"... [truncated {len(text) - limit} chars]"


def _safe_tool_input(value: object) -> object:
    if not isinstance(value, dict):
        return _truncate(value, 500)
    keep: dict[str, object] = {}
    for key in ("command", "cmd", "path", "file_path", "workdir", "description"):
        if key in value:
            keep[key] = _truncate(value.get(key), 500)
    if keep:
        keep["_keys"] = sorted(str(key) for key in value.keys())
        return keep
    return {"_keys": sorted(str(key) for key in value.keys())}


def _safe_payload(payload: dict) -> dict:
    safe: dict[str, object] = {}
    for key in (
        "session_id",
        "turn_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "model",
        "permission_mode",
        "tool_name",
    ):
        if key in payload:
            safe[key] = payload.get(key)
    for key in ("prompt", "message", "last_assistant_message"):
        if key in payload:
            safe[key] = _truncate(payload.get(key), 500)
    if "tool_input" in payload:
        safe["tool_input"] = _safe_tool_input(payload.get("tool_input"))
    if "tool_response" in payload:
        safe["tool_response_chars"] = len(str(payload.get("tool_response") or ""))
    return safe


def _level(event_name: str | None) -> str:
    if event_name in {"Notification", "PermissionRequest"}:
        return "needs_feedback"
    if event_name == "Stop":
        return "done"
    return "running"


def _classification(event_name: str | None) -> tuple[str, str, bool, int]:
    if event_name == "PermissionRequest":
        return "attention", "needs_approval", True, 100
    if event_name == "Notification":
        return "attention", "needs_input", True, 95
    if event_name == "Stop":
        return "completion", "completed", False, 15
    if event_name in {"PreToolUse", "PostToolUse"}:
        return "progress", "running", False, 30
    if event_name in {"SessionStart", "UserPromptSubmit"}:
        return "lifecycle", "running", False, 20
    return "progress", "running", False, 10


def _status_label(level: str) -> str:
    if level == "needs_feedback":
        return "需要你"
    if level == "done":
        return "已完成"
    return "运行中"


def _should_alert(level: str) -> bool:
    return level in {"done", "needs_feedback"}


def _should_preserve_attention(existing: dict | None, event_name: str | None, requires_user: bool) -> bool:
    if not existing or requires_user:
        return False
    if existing.get("requires_user") is not True:
        return False
    return event_name not in {"UserPromptSubmit", "Stop", "SessionStart"}


def _summary(payload: dict, level: str) -> tuple[str, str, str]:
    event = str(payload.get("hook_event_name") or payload.get("event") or "Codex")
    cwd = str(payload.get("cwd") or "")
    workspace = _workspace_name(cwd)

    prompt = payload.get("prompt")
    message = payload.get("message")
    assistant = payload.get("last_assistant_message")
    tool = payload.get("tool_name")

    if event == "SessionStart":
        return f"Codex 运行中 · {workspace}", "线程已启动，等待下一步任务", "线程已启动"
    if event in {"Notification", "PermissionRequest"}:
        text = _clean_text(prompt or message or assistant, "Codex 需要你处理下一步")
        return f"Codex 需要你 · {workspace}", text[:180], text[:120]
    if event == "UserPromptSubmit":
        text = _clean_text(prompt, "已收到新指令")
        return f"Codex 运行中 · {workspace}", f"已收到指令：{text[:150]}", text[:120]
    if event == "Stop":
        text = _clean_text(assistant, "本轮已完成")
        return f"Codex 已完成 · {workspace}", text[:180], text[:120]
    if event == "PreToolUse":
        tool_name = _clean_text(tool, "工具")
        return f"Codex 运行中 · {workspace}", f"正在使用 {tool_name}", f"使用 {tool_name}"
    if event == "PostToolUse":
        tool_name = _clean_text(tool, "工具")
        return f"Codex 运行中 · {workspace}", f"已完成 {tool_name}，继续处理", f"完成 {tool_name}"

    return f"Codex {_status_label(level)} · {workspace}", f"{workspace} 中的 {event}", event


def _session_key(payload: dict) -> str:
    session_id = payload.get("session_id")
    if session_id:
        return str(session_id)
    turn_id = payload.get("turn_id")
    if turn_id:
        return f"turn:{turn_id}"
    cwd = str(payload.get("cwd") or "workspace")
    return f"cwd:{cwd}"


def _read_sessions() -> dict:
    if not SESSIONS_PATH.exists():
        return {}
    try:
        data = json.loads(SESSIONS_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _write_sessions(event: dict) -> None:
    sessions = _read_sessions()
    key = _session_key(event["raw"])
    existing = sessions.get(key)
    if _should_preserve_attention(existing, event["hook_event_name"], event["requires_user"]):
        preserved = dict(existing)
        preserved["timestamp"] = event["timestamp"]
        preserved["event_id"] = event["event_id"]
        preserved["raw_last_progress"] = {
            "hook_event_name": event["hook_event_name"],
            "progress": event["progress"],
            "timestamp": event["timestamp"],
        }
        sessions[key] = preserved
    else:
        sessions[key] = {
            "event_id": event["event_id"],
            "timestamp": event["timestamp"],
            "hook_event_name": event["hook_event_name"],
            "kind": event["kind"],
            "phase": event["phase"],
            "level": event["level"],
            "status_label": event["status_label"],
            "requires_user": event["requires_user"],
            "should_alert": event["should_alert"],
            "priority": event["priority"],
            "session_id": event["session_id"],
            "turn_id": event["turn_id"],
            "transcript_path": event["transcript_path"],
            "cwd": event["cwd"],
            "workspace": event["workspace"],
            "project": event["project"],
            "model": event["model"],
            "title": event["title"],
            "body": event["body"],
            "progress": event["progress"],
        }

    recent = sorted(
        sessions.items(),
        key=lambda item: float(item[1].get("timestamp") or 0),
        reverse=True,
    )[:30]
    pruned = dict(recent)

    tmp = SESSIONS_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(pruned, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, SESSIONS_PATH)


def _write_event(payload: dict) -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)

    now = time.time()
    cwd = str(payload.get("cwd") or "")
    event_name = payload.get("hook_event_name")
    level = _level(event_name)
    kind, phase, requires_user, priority = _classification(event_name)
    title, body, progress = _summary(payload, level)

    event = {
        "event_id": f"{int(now * 1000)}-{uuid.uuid4().hex[:10]}",
        "timestamp": now,
        "hook_event_name": event_name,
        "kind": kind,
        "phase": phase,
        "level": level,
        "status_label": _status_label(level),
        "requires_user": requires_user,
        "should_alert": _should_alert(level),
        "priority": priority,
        "session_id": payload.get("session_id"),
        "turn_id": payload.get("turn_id"),
        "transcript_path": payload.get("transcript_path"),
        "cwd": cwd,
        "workspace": _workspace_name(cwd),
        "project": _workspace_name(cwd),
        "model": payload.get("model"),
        "title": title,
        "body": body,
        "progress": progress,
        "raw": _safe_payload(payload),
    }

    with LOCK_PATH.open("w", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with EVENTS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")

        _write_sessions(event)

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
