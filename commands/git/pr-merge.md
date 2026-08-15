---
description: 按编号合并 PR/MR（自动识别 gh/glab），删除原分支，切回主干并更新代码
---

# 任务
本命令由 `git-kit` skill 的 **pr-merge 分支**实现。

用 `skill` 工具加载 `git-kit`，将本次请求视为 `pr-merge` 意图。

# 参数
`$1` 为要合并的 PR/MR 编号（可选）。例如 `/git/pr-merge 123`。
未提供时从上下文探测当前分支关联的开放 PR/MR 并**先展示给用户三选项确认（是 / 否 / 自定义 id）**；探测不到则必须向用户索要编号（详见 skill `references/pr-merge.md`「确定编号」）。
