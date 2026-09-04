---
description: 基于代码变更生成 commit message 并自动提交推送到远端；稳定分支（main/master/含 release 关键字）时自动创建分支
---

# 任务
本命令由 `git-kit` skill 的 **commit-push 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `commit-push` 意图执行。

# 参数
$ARGUMENTS

> 可选补充说明；若上方参数为空，基于代码变更分析。
