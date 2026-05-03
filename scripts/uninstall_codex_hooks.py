#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import time
from pathlib import Path


def main() -> int:
    hooks_json = Path.home() / ".codex" / "hooks.json"
    if not hooks_json.exists():
        return 0

    backup = hooks_json.with_suffix(f".json.bak-codex-status-bar-uninstall-{int(time.time())}")
    shutil.copy2(hooks_json, backup)
    data = json.loads(hooks_json.read_text(encoding="utf-8"))

    for groups in data.get("hooks", {}).values():
        for group in groups:
            target_hooks = group.get("hooks", [])
            if isinstance(target_hooks, list):
                group["hooks"] = [
                    item for item in target_hooks
                    if not (isinstance(item, dict) and "codex_status_hook.py" in item.get("command", ""))
                ]

    hooks_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
