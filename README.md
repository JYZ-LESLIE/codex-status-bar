# Codex Status Bar / Codex 状态栏

Codex Status Bar 是一个给 Codex 用的 macOS 菜单栏 + 顶部岛状提醒工具，默认中文运行。它适合在 MacBook 刘海屏和外接显示器之间切换的人。

它监听 Codex hook 事件，写入本地事件日志，在菜单栏显示最新状态，在屏幕顶部显示岛状提示，并在“收到指令 / 已完成 / 需要反馈”时发送 macOS 通知。

English: this is a small Chinese-first macOS menu bar and top-island notifier for Codex.

## Why this exists

Vibe Island 和 Open Island 证明了 AI coding agent 需要一个轻量的环境状态提示层。但在我的实际工作里，经常使用外接显示器，刘海不一定可见；同时 Codex 历史文件很大时，全量扫描历史 rollout 成本很高。

This project focuses on that narrower problem:

- 菜单栏优先，所以外接显示器也能看到
- 当前屏幕顶部显示岛状浮层，兼容 MacBook 刘海屏
- 明确显示 `运行中`、`已完成`、`需要反馈`
- 收到指令、完成、需要反馈时发通知
- 不扫描历史 rollout 文件
- hook fail-open，状态栏没运行也不会阻塞 Codex

## Install

```bash
./install.sh
```

安装器会构建一个原生 macOS 小 app，安装 hook sink，更新 `~/.codex/hooks.json`，并添加 LaunchAgent，让它登录后自动启动。

## Uninstall

```bash
./uninstall.sh
```

事件历史会保留在 `~/Library/Application Support/CodexStatusBar/`。

## What changed versus the inspiration

这不是 Vibe Island 或 Open Island 的克隆。它借鉴的是“coding agent 需要环境状态提示”的产品洞察，但实现面做了这些调整：

- 菜单栏 + 轻量顶部岛状浮层
- 同时支持 MacBook 刘海屏和外接显示器
- 只接当前 Codex hook 事件
- 避免扫描 `~/.codex/sessions/**/rollout-*.jsonl`
- 增加本地 JSONL 事件日志
- hook sink 独立于 app 运行，app 没开也不阻塞 Codex

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
