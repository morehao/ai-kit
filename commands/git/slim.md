---
description: 将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动
---

# 任务
把当前目录的 git 仓库瘦身：去掉历史中大文件对象累积，缩成浅克隆。默认保留最近 30 天历史；若用户传入 `$1`，则以天为单位（`/git/slim 90` = 保留 90 天）。**最高优先级：绝不丢失任何本地未提交改动。**

# 执行流程（每步失败立即停止并报错）
1. **前置安全校验（自提交检测）**：若仓库存在作者或提交者为当前 git 用户本人的提交，立即报错中止，不执行任何操作：
   ```sh
   name="$(git config user.name)"; email="$(git config user.email)"
   if [ -n "$name" ] && git log --all --author="$name" --format='%H' | grep -q .; then
     echo "检测到本人提交（作者=$name），禁止执行本命令" >&2; exit 1
   fi
   if [ -n "$email" ] && git log --all --committer="$email" --format='%H' | grep -q .; then
     echo "检测到本人提交（提交者=$email），禁止执行本命令" >&2; exit 1
   fi
   ```
2. 记录瘦身前体积：`du -sh .git`
3. 安全检查：`git status --porcelain`。若有改动（M/A/D/??），先缓存：`git stash push -u -m "slim-backup-$(date +%s)"`
4. 解析保留深度：默认 `30 days ago`；若提供了 `$1` 数字，用 `$1 days ago`
5. 浅拉取：`git fetch --shallow-since="<深度>" --prune origin "$(git branch --show-current)"`
6. 本地分支对齐远端（不损坏已 stash 改动）：优先 `git merge --ff-only origin/<当前分支>`；若 ff 失败，改用 `git reset --soft origin/<当前分支>` 保留工作树
7. 收缩：`git reflog expire --expire=now --all && git gc --prune=now`
8. 恢复本地改动：`git stash pop`（若有 stash）
9. 核对工作区：`git status --porcelain` 与步骤 3 一致；输出体积对比 `du -sh .git`

# 验收标准
- `.git` 体积较步骤 1 明显缩小
- `git pull` 可正常执行
- 本地改动完整保留

# 警示
- 30 天（或 `$N` 天）以前的提交将不可见；需要时可 `git fetch --unshallow` 恢复完整历史（空间回涨）
- 执行前请确认当前分支即你想要对齐的目标分支
