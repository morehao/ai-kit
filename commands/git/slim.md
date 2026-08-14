---
description: 将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动
---

# 任务
把当前目录的 git 仓库瘦身：去掉历史中大文件对象累积，缩成浅克隆。默认保留最近 30 天历史；若用户传入 `$1`，则以天为单位（`/git/slim 90` = 保留 90 天）。**最高优先级：绝不丢失任何本地未提交改动。**

本命令在每一步记录开始时刻与耗时，结束后输出各步骤耗时汇总，用于定位耗时瓶颈；任一步失败会立即中止，并在报错信息中带出"失败步骤 + 累计耗时"。

# 计时与失败捕获机制（先定义，后执行流程使用）

以下代码在 bash / zsh / sh 下均可运行（已实测通过）：

```sh
set -e
TOTAL_START=$(date +%s)
RUN_STEP=
# 各步骤耗时占位变量
T2= T3= T5= T6= T7= T8= T9a= T9b=

# 兜底：任何未被 run 捕获的异常退出时，若仍处于某步骤，则打印失败信息
trap 'if [ -n "$RUN_STEP" ]; then
  echo "[兜底中止] 失败于: $RUN_STEP, 累计耗时 $(( $(date +%s) - TOTAL_START ))s" >&2
fi' EXIT

run() {
  local __step="$1" __var="$2" __s __code; shift 2
  RUN_STEP="$__step"
  echo "[$(date '+%H:%M:%S')] -> $__step"
  __s=$(date +%s)
  "$@" && __code=0 || __code=$?   # 吸收失败，避免 zsh err_exit 直接跳过函数体
  if [ $__code -ne 0 ]; then
    RUN_STEP=
    echo "[中止] 失败于: $__step, 累计耗时 $(( $(date +%s) - TOTAL_START ))s" >&2
    exit $__code
  fi
  eval "$__var=\$(( $(date +%s) - __s ))"
  printf '  [完成 %s, 耗时 %ss / 累计 %ss]\n' "$__step" "$(( $(date +%s) - __s ))" "$(( $(date +%s) - TOTAL_START ))"
  RUN_STEP=
}
```

# 执行流程（每步失败立即停止并报错）

0. **注入计时机制**：直接引入上一节"计时与失败捕获机制"的完整代码块。

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
2. 记录瘦身前体积：
   ```sh
   run "2. 记录瘦身前体积" T2 du -sh .git
   ```
3. 安全检查并缓存改动：`git status --porcelain`；若有改动（M/A/D/??），先缓存：
   ```sh
   run "3. 安全检查与缓存" T3 sh -c '
     git status --porcelain
     if ! git diff --quiet || ! git diff --cached --quiet || ! git ls-files --others --exclude-standard --quiet; then
       git stash push -u -m "slim-backup-$(date +%s)"
     fi
   '
   ```
4. 解析保留深度：默认 `30 days ago`；若提供了 `$1` 数字，用 `$1 days ago`：
   ```sh
   if [[ "$1" =~ ^[0-9]+$ ]]; then DEPTH="$1 days ago"; else DEPTH="30 days ago"; fi
   ```
5. 浅拉取：
   ```sh
   run "5. 浅拉取" T5 git fetch --shallow-since="$DEPTH" --prune origin "$(git branch --show-current)"
   ```
6. 本地分支对齐远端（不损坏已 stash 改动）：优先 ff 合并；失败则软重置保留工作树：
   ```sh
   BR="$(git branch --show-current)"
   run "6. 合并远端分支" T6 sh -c 'git merge --ff-only "origin/${BR}" || git reset --soft "origin/${BR}"'
   ```
7. 收缩 reflog 并 gc：
   ```sh
   run "7. 收缩 reflog+gc" T7 sh -c 'git reflog expire --expire=now --all && git gc --prune=now'
   ```
8. 恢复本地改动（若有 stash）：
   ```sh
   run "8. 恢复本地改动" T8 sh -c 'git stash list | grep -q slim-backup && git stash pop || true'
   ```
9. 核对工作区并输出体积对比：
   ```sh
   run "9. 核对工作区" T9a git status --porcelain
   run "9. 输出体积对比" T9b du -sh .git
   ```

# 耗时汇总（在所有步骤完成后输出）

```sh
echo "==== 耗时汇总 ===="
echo "2. 记录瘦身前体积 : ${T2:-0}s"
echo "3. 安全检查与缓存 : ${T3:-0}s"
echo "5. 浅拉取         : ${T5:-0}s"
echo "6. 合并远端分支   : ${T6:-0}s"
echo "7. 收缩 reflog+gc : ${T7:-0}s"
echo "8. 恢复本地改动   : ${T8:-0}s"
echo "9. 核对工作区     : ${T9a:-0}s"
echo "9. 输出体积对比   : ${T9b:-0}s"
echo "总耗时           : $(( $(date +%s) - TOTAL_START ))s"
```

# 验收标准
- `.git` 体积较步骤 2 明显缩小
- `git pull` 可正常执行
- 本地改动完整保留
- 输出体现了各步骤耗时汇总，便于定位耗时瓶颈

# 警示
- 30 天（或 `$N` 天）以前的提交将不可见；需要时可 `git fetch --unshallow` 恢复完整历史（空间回涨）
- 执行前请确认当前分支即你想要对齐的目标分支
