---
description: 基于代码变更生成 commit message 并自动提交推送到远端；稳定分支（main/master/含 release 关键字）时自动创建分支
---

# 任务
本命令由 `git-kit` skill 的 **commit-push 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `commit-push` 意图。

# 稳定分支自动建分支
若当前在稳定分支（`main`/`master`，或分支名含 `release` 关键字），先基于代码变动自动创建分支，再执行 commit-push，避免污染稳定分支
(实现见 skill `references/commit-push.md` 的「稳定分支自动建分支」节)。
