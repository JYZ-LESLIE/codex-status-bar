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
import re
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


def _json_title(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text.startswith("{"):
        return None
    try:
        parsed = json.loads(text)
    except Exception:
        return None
    if not isinstance(parsed, dict):
        return None
    title = parsed.get("title")
    if not title:
        return None
    return str(title)


def _display_text(value: object, fallback: str) -> str:
    value = _json_title(value) or value
    text = _clean_text(value, fallback)
    text = re.sub(r"^#+\s*", "", text)
    text = text.replace("`", "").replace("*", "")
    text = re.sub(r"\s+", " ", text).strip()
    return text or fallback


def _is_internal_summary(text: object) -> bool:
    value = _display_text(text, "").lower()
    return value.startswith("memory summary") or value.startswith("context of everything")


def _compact_title(text: object, fallback: str) -> str:
    value = _display_text(text, fallback)
    for sep in ("。", "，", ".", "；", ";", "\n"):
        if sep in value:
            value = value.split(sep, 1)[0]
            break
    return value[:36].strip() or fallback


def _thread_title_from_transcript(path_value: object) -> str | None:
    if not path_value:
        return None
    path = Path(str(path_value)).expanduser()
    if not path.exists() or not path.is_file():
        return None

    fallback_user_title: str | None = None
    try:
        with path.open("r", encoding="utf-8") as handle:
            for index, line in enumerate(handle):
                if index > 260:
                    break
                try:
                    item = json.loads(line)
                except Exception:
                    continue
                payload = item.get("payload") if isinstance(item, dict) else None
                if not isinstance(payload, dict):
                    continue
                if payload.get("type") == "thread_name_updated":
                    title = payload.get("thread_name")
                    if title:
                        return _compact_title(title, "Codex 任务")
                if payload.get("type") == "user_message" and not fallback_user_title:
                    message = str(payload.get("message") or "").strip()
                    if message and not message.startswith("# AGENTS.md instructions"):
                        fallback_user_title = _compact_title(message, "Codex 任务")
                if item.get("type") == "response_item":
                    inner = payload.get("payload") if isinstance(payload.get("payload"), dict) else payload
                    if isinstance(inner, dict) and inner.get("role") == "user" and not fallback_user_title:
                        text = json.dumps(inner.get("content") or "", ensure_ascii=False)
                        if text and "# AGENTS.md instructions" not in text:
                            fallback_user_title = _compact_title(text, "Codex 任务")
    except Exception:
        return None
    return fallback_user_title


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


def _tool_text(payload: dict) -> str:
    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict):
        parts = []
        for key in ("command", "cmd", "description", "path", "file_path", "workdir"):
            if tool_input.get(key):
                parts.append(str(tool_input.get(key)))
        return " ".join(parts)
    return str(tool_input or "")


def _task_color(task_type: str) -> str:
    return {
        "feedback": "#C2410C",
        "code": "#2563EB",
        "test": "#0F766E",
        "release": "#7C3AED",
        "git": "#4F46E5",
        "research": "#475569",
        "browser": "#0284C7",
        "document": "#B45309",
        "complete": "#15803D",
        "start": "#6B7280",
        "tool": "#4B5563",
    }.get(task_type, "#4B5563")


def _status_color(level: str) -> str:
    if level == "needs_feedback":
        return "#C2410C"
    if level == "done":
        return "#15803D"
    return "#2563EB"


def _display_fields(payload: dict, event_name: str | None, task_label: str, body: str, progress: str) -> tuple[str, str, bool]:
    cwd = str(payload.get("cwd") or "")
    workspace = _workspace_name(cwd)
    transcript_title = _thread_title_from_transcript(payload.get("transcript_path"))
    prompt = payload.get("prompt") or payload.get("message")
    assistant = payload.get("last_assistant_message")
    internal = workspace == "screen_recording" or _is_internal_summary(body) or _is_internal_summary(progress)

    if transcript_title:
        title = transcript_title
    elif prompt:
        title = _compact_title(prompt, "Codex 任务")
    elif internal:
        title = "后台摘要"
    elif event_name == "Stop" and assistant:
        title = _compact_title(assistant, "已完成任务")
    else:
        title = workspace if workspace != "Workspace" else "Codex 任务"

    if internal:
        subtitle = "系统后台摘要，默认不进入任务看板"
    elif event_name in {"PreToolUse", "PostToolUse"}:
        subtitle = _display_text(progress, "正在处理")
    elif event_name == "UserPromptSubmit":
        subtitle = _display_text(progress, "已收到指令")
    else:
        subtitle = _display_text(body or progress, "等待更新")

    return title[:46], subtitle[:160], internal


def _infer_task(payload: dict, event_name: str | None, level: str) -> tuple[str, str, str]:
    tool = str(payload.get("tool_name") or "")
    tool_lower = tool.lower()
    text = " ".join(
        [
            str(event_name or ""),
            tool,
            _tool_text(payload),
            str(payload.get("prompt") or ""),
            str(payload.get("message") or ""),
        ]
    ).lower()

    if level == "needs_feedback":
        if event_name == "PermissionRequest":
            return "feedback", "要确认", _task_color("feedback")
        return "feedback", "要反馈", _task_color("feedback")
    if event_name == "Stop":
        return "complete", "完成", _task_color("complete")
    if event_name in {"SessionStart", "UserPromptSubmit"}:
        return "start", "新任务", _task_color("start")
    if "apply_patch" in text or "patch" in tool_lower:
        return "code", "写代码", _task_color("code")
    if "gh release" in text or "git push" in text or "git tag" in text or "release" in text:
        return "release", "发布", _task_color("release")
    if "git " in text or tool_lower == "git":
        return "git", "Git", _task_color("git")
    if any(word in text for word in ("test", "pytest", "swift test", "npm test", "build", "swiftc", "py_compile")):
        return "test", "测试", _task_color("test")
    if any(word in text for word in ("rg ", "grep", "sed ", "cat ", "ls ", "find ", "tail ", "head ", "nl ")):
        return "research", "查看", _task_color("research")
    if any(word in text for word in ("web", "search", "open", "fetch", "curl", "http")):
        return "research", "资料", _task_color("research")
    if any(word in tool_lower for word in ("browser", "computer", "playwright")):
        return "browser", "浏览器", _task_color("browser")
    if any(word in text for word in ("readme", ".md", ".txt", "doc", "release_notes")):
        return "document", "文档", _task_color("document")
    if tool:
        return "tool", "工具", _task_color("tool")
    return "tool", "处理", _task_color("tool")


def _status_label(level: str) -> str:
    if level == "needs_feedback":
        return "需要你"
    if level == "done":
        return "已完成"
    return "运行中"


def _should_alert(level: str) -> bool:
    return level in {"done", "needs_feedback"}


def _has_meaningful_activity(existing: dict | None) -> bool:
    if not existing:
        return False
    tracked_activity = any(
        existing.get(key) is True
        for key in ("had_user_prompt", "had_tool_activity")
    )
    visible_activity = existing.get("show_in_board") is True and existing.get("hook_event_name") != "SessionStart"
    return tracked_activity or visible_activity


def _session_flags(existing: dict | None, event_name: str | None, is_internal: bool) -> tuple[bool, bool, bool]:
    had_user_prompt = bool(existing and existing.get("had_user_prompt")) or event_name == "UserPromptSubmit"
    had_tool_activity = bool(existing and existing.get("had_tool_activity")) or event_name in {"PreToolUse", "PostToolUse"}

    if is_internal:
        return had_user_prompt, had_tool_activity, False
    if event_name == "SessionStart":
        return had_user_prompt, had_tool_activity, False
    if event_name == "Stop":
        return had_user_prompt, had_tool_activity, _has_meaningful_activity(existing)
    return had_user_prompt, had_tool_activity, True


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
        preserved["had_user_prompt"] = bool(existing.get("had_user_prompt")) or bool(event.get("had_user_prompt"))
        preserved["had_tool_activity"] = bool(existing.get("had_tool_activity")) or bool(event.get("had_tool_activity"))
        preserved["show_in_board"] = bool(existing.get("show_in_board", True))
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
            "task_type": event["task_type"],
            "task_label": event["task_label"],
            "task_color": event["task_color"],
            "status_color": event["status_color"],
            "display_title": event["display_title"],
            "display_subtitle": event["display_subtitle"],
            "is_internal": event["is_internal"],
            "show_in_board": event["show_in_board"],
            "had_user_prompt": event["had_user_prompt"],
            "had_tool_activity": event["had_tool_activity"],
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
    task_type, task_label, task_color = _infer_task(payload, event_name, level)
    title, body, progress = _summary(payload, level)
    display_title, display_subtitle, is_internal = _display_fields(payload, event_name, task_label, body, progress)
    existing = _read_sessions().get(_session_key(payload))
    had_user_prompt, had_tool_activity, show_in_board = _session_flags(existing, event_name, is_internal)
    should_alert = _should_alert(level) and show_in_board

    event = {
        "event_id": f"{int(now * 1000)}-{uuid.uuid4().hex[:10]}",
        "timestamp": now,
        "hook_event_name": event_name,
        "kind": kind,
        "phase": phase,
        "level": level,
        "status_label": _status_label(level),
        "requires_user": requires_user,
        "should_alert": should_alert,
        "priority": priority if show_in_board else 0,
        "task_type": task_type,
        "task_label": task_label,
        "task_color": task_color,
        "status_color": _status_color(level),
        "display_title": display_title,
        "display_subtitle": display_subtitle,
        "is_internal": is_internal,
        "show_in_board": show_in_board,
        "had_user_prompt": had_user_prompt,
        "had_tool_activity": had_tool_activity,
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
