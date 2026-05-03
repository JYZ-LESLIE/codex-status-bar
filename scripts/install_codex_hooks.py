#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import sys
import time
from pathlib import Path


EVENTS = (
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "Notification",
    "Stop",
)


def quote_command(path: str) -> str:
    return "'" + path.replace("'", "'\\''") + "'"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: install_codex_hooks.py /path/to/codex_status_hook.py", file=sys.stderr)
        return 2

    hook_path = str(Path(sys.argv[1]).expanduser().resolve())
    command = quote_command(hook_path)
    codex_dir = Path.home() / ".codex"
    hooks_json = codex_dir / "hooks.json"
    codex_dir.mkdir(parents=True, exist_ok=True)

    if hooks_json.exists():
        backup = hooks_json.with_suffix(f".json.bak-codex-status-bar-{int(time.time())}")
        shutil.copy2(hooks_json, backup)
        data = json.loads(hooks_json.read_text(encoding="utf-8"))
    else:
        data = {}

    hooks = data.setdefault("hooks", {})
    for event in EVENTS:
        groups = hooks.setdefault(event, [])
        if not groups:
            group = {"hooks": []}
            if event == "SessionStart":
                group["matcher"] = "startup|resume"
            groups.append(group)

        target_group = groups[0]
        target_hooks = target_group.setdefault("hooks", [])
        target_hooks[:] = [
            item for item in target_hooks
            if not (isinstance(item, dict) and "codex_status_hook.py" in item.get("command", ""))
        ]
        target_hooks.append({"type": "command", "command": command, "timeout": 10})

    hooks_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
