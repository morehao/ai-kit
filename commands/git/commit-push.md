---
description: 基于代码变更生成 commit message 并自动提交推送到远端；main 分支时自动创建分支
---

# 任务
本命令由 `git-kit` skill 的 **commit-push 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `commit-push` 意图。

# 主干自动建分支
若当前在 `main`/`master` 分支，先基于代码变动自动创建分支，再执行 commit-push，避免污染主干
(实现见 skill `references/commit-push.md` 的「main/master 自动建分支」节)。
