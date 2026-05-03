# Codex Status Bar v0.3.0

中文运行版。

## 变化

- 菜单栏状态改为中文：
  - `Codex 运行中`
  - `Codex 已完成`
  - `Codex 需要你`
- 顶部岛状浮层状态改为中文：
  - `运行中`
  - `已完成`
  - `需要反馈`
- hook 写入的默认标题和正文改为中文。
- 通知默认文案改为中文。
- README 改为中文优先，同时保留英文说明入口。

## 保持不变

- 仍然兼容 MacBook 刘海屏和外接显示器。
- 仍然不扫描历史 Codex rollout 文件。
- hook 仍然 fail-open，不会阻塞 Codex。

## 开源致谢

继续感谢 Vibe Island 的环境控制面产品启发，以及 `Octane0411/open-vibe-island`、`wxtsky/CodeIsland` 等社区项目对 agent 状态提示和 Codex hook 工作流的探索。

本项目没有 vendored 这些项目的源代码。
