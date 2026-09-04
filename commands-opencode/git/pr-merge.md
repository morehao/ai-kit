---
description: 按编号合并 PR/MR（自动识别 gh/glab），删除原分支，切回主干并更新代码
---

# 任务
本命令由 `git-kit` skill 的 **pr-merge 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `pr-merge` 意图执行。

# 参数
$ARGUMENTS

> 可选 PR/MR 编号或 URL；若上方参数为空，探测当前分支关联的开放 PR/MR，探测不到再向用户索取。
