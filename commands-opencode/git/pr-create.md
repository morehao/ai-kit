---
description: 基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab）；合并 PR/MR 请用 /git/pr-merge
---

# 任务
本命令由 `git-kit` skill 的 **pr-create 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `pr-create` 意图执行。

# 参数
$ARGUMENTS

> 可选目标分支名；若上方参数为空，探测目标仓库默认分支。
