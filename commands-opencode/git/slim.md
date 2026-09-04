---
description: 将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动
---

# 任务
本命令由 `git-kit` skill 的 **slim 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `slim` 意图执行。

# 参数
$ARGUMENTS

> 可选保留天数 N；若上方参数为空，默认保留最近 30 天历史。
