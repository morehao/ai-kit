---
description: 端到端发版：探测版本文件与最新 tag，确认版本号后升版本、提交、打 tag、推送并验证发布结果
---

# 任务
本命令由 `git-kit` skill 的 **release 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `release` 意图执行。

# 参数
$ARGUMENTS

> 可选版本号或档位（如 `v1.2.0`、`1.2.0`、`--patch`/`--minor`/`--major`）；若上方参数为空，探测版本文件、最新 tag 与下一版本候选，先展示给用户确认版本号与目标分支再继续。只打 tag、不改仓库文件用 `/git/tag`。
