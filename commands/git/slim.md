---
description: 将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动
---

# 任务
把当前目录的 git 仓库瘦身：去掉历史中大文件对象累积，缩成浅克隆。默认保留最近 30 天历史；若传入 `$1`，则以天为单位（`/git/slim 90` = 保留 90 天）。**最高优先级：绝不丢失任何本地未提交改动。**

本命令的完整执行逻辑（计时与失败捕获、9 步流程、耗时汇总）抽成独立脚本 **`git-slim.sh`**，本命令与 git-kit skill 的 slim 分支共用同一脚本，避免内容漂移。

## 运行方式

定位并运行脚本：

```
SCRIPT="$(cd "$(dirname "$0")" && pwd)/../../../skills/git-kit/scripts/git-slim.sh"
bash "$SCRIPT" "$1"
```

或用已安装的显式路径运行：

```
/path/to/ai-kit/skills/git-kit/scripts/git-slim.sh [天数]
```

无参数 → 保留最近 30 天；传数字 `N` → 保留 `N` 天。

## 脚本内部流程（供参考/排障）

1. 注入计时与失败捕获机制（`run()`/`trap`），每步记录耗时，失败立即带出"失败步骤+累计耗时"
2. 前置安全校验（自提交检测）：存在作者/提交者为当前 git 用户本人的提交即中止
3. 记录瘦身前体积
4. 安全检查并缓存改动（`git stash push -u` 备份本地改动）
5. 解析保留深度（默认 `30 days ago`）
6. 浅拉取：`git fetch --shallow-since=<深度> --prune origin <当前分支>`
7. 本地分支对齐远端（`git merge --ff-only`，失败则 `git reset --soft`）
8. 收缩 reflog 并 gc（`git reflog expire` + `git gc --prune=now`）
9. 恢复本地改动（`git stash pop`）
10. 核对工作区并输出体积对比 + 耗时汇总

## 验收标准

- `.git` 体积较步骤 3 明显缩小
- `git pull` 可正常执行
- 本地改动完整保留
- 输出体现了各步骤耗时汇总，便于定位耗时瓶颈

## 警示

- 30 天（或 `$N` 天）以前的提交将不可见；需要时可 `git fetch --unshallow` 恢复完整历史（空间回涨）
- 执行前请确认当前分支即你想要对齐的目标分支
