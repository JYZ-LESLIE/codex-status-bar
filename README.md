# Codex Status Bar / Codex 状态栏

Codex Status Bar 是一个给 Codex 用的 macOS 菜单栏 + 顶部岛状提醒工具，默认中文运行。它适合在 MacBook 刘海屏和外接显示器之间切换的人。

它监听 Codex hook 事件，写入本地事件日志，在菜单栏显示卡片式任务看板。运行中只静默更新菜单；只有“已完成 / 需要反馈”时才在屏幕顶部显示岛状提示并发送 macOS 通知。

English: this is a small Chinese-first macOS menu bar and top-island notifier for Codex.

## Why this exists

Vibe Island 和 Open Island 证明了 AI coding agent 需要一个轻量的环境状态提示层。但在我的实际工作里，经常使用外接显示器，刘海不一定可见；同时 Codex 历史文件很大时，全量扫描历史 rollout 成本很高。

This project focuses on that narrower problem:

- 菜单栏优先，所以外接显示器也能看到
- 当前屏幕顶部显示岛状浮层，兼容 MacBook 刘海屏
- 明确显示 `运行中`、`已完成`、`需要反馈`
- 同时显示多个 Codex 会话的项目名和最新进度
- 菜单按 `需要你看 / 运行中 / 最近完成` 分组
- 每个会话显示为两行任务卡片：第一行任务标题，第二行进度摘要
- 用颜色区分任务：需要确认、写代码、测试构建、GitHub 发布、完成、资料查看
- 优先读取 Codex 线程名，避免把 `codex`、`screen_recording` 当成任务名
- 自动隐藏 `screen_recording` / `Memory summary` 这类后台摘要
- 会话行可直接点击打开对应 Codex 线程
- 颜色说明收在二级菜单里，不占主任务列表空间
- 写代码、跑工具、收到指令时不弹窗，只在菜单里更新
- 完成、需要反馈时才发明显提醒
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
- 增加多会话进度账本，方便同时跑多个 Codex 对话
- 区分静默进度更新和必须看见的反馈提醒
- 为事件增加 `kind / phase / requires_user / priority` 状态字段
- 为事件增加 `task_type / task_label / task_color / status_color` 任务分诊字段
- 为事件增加 `display_title / display_subtitle / is_internal` 展示字段
- 避免扫描 `~/.codex/sessions/**/rollout-*.jsonl`
- 增加本地 JSONL 事件日志
- 大工具输出只记录长度，不把完整响应塞进事件日志
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

Runtime files:

- `~/Library/Application Support/CodexStatusBar/latest.json`: latest event.
- `~/Library/Application Support/CodexStatusBar/sessions.json`: latest state for recent Codex sessions.
- `~/Library/Application Support/CodexStatusBar/events.jsonl`: append-only event log.

## License

MIT.
