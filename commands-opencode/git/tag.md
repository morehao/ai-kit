---
description: 查看最新 tag 与来源分支，选择要打 tag 的分支与版本号，构建注记 tag 并推送到远端
---

# 任务
本命令由 `git-kit` skill 的 **tag 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `tag` 意图。

# 参数
`$1` 为可选的目标 tag 名或分支名（如 `/git/tag v1.2.4`、`/git/tag main`）。
未提供时按流程探测最新 tag 与来源分支、候选分支、候选版本号并**先展示给用户选择确认**（详见 skill `references/tag.md`）。
