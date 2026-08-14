#!/usr/bin/env bash
# git-slim.sh —— 将当前目录的 git 仓库瘦身为浅克隆
# 默认保留最近 30 天历史；传 `$1` 数字则以天为单位（git-slim.sh 90 = 保留 90 天）
# 最高优先级：绝不丢失任何本地未提交改动。
# 每步记录开始时刻与耗时，结束后输出各步骤耗时汇总；任一步失败会立即中止并带出失败步骤+累计耗时。
set -e

echo "[$(date '+%H:%M:%S')] -> 0. 注入计时与失败捕获机制"

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

# 1. 前置安全校验（自提交检测）：仓库存在作者/提交者为当前 git 用户本人的提交则中止
name="$(git config user.name)"; email="$(git config user.email)"
if [ -n "$name" ] && git log --all --author="$name" --format='%H' | grep -q .; then
  echo "检测到本人提交（作者=$name），禁止执行本命令" >&2; exit 1
fi
if [ -n "$email" ] && git log --all --committer="$email" --format='%H' | grep -q .; then
  echo "检测到本人提交（提交者=$email），禁止执行本命令" >&2; exit 1
fi

# 2. 记录瘦身前体积
run "2. 记录瘦身前体积" T2 du -sh .git

# 3. 安全检查并缓存改动
run "3. 安全检查与缓存" T3 sh -c '
  git status --porcelain
  if ! git diff --quiet || ! git diff --cached --quiet || ! git ls-files --others --exclude-standard --quiet; then
    git stash push -u -m "slim-backup-$(date +%s)"
  fi
'

# 4. 解析保留深度
if [[ "$1" =~ ^[0-9]+$ ]]; then DEPTH="$1 days ago"; else DEPTH="30 days ago"; fi

# 5. 浅拉取
run "5. 浅拉取" T5 git fetch --shallow-since="$DEPTH" --prune origin "$(git branch --show-current)"

# 6. 本地分支对齐远端（不损坏已 stash 改动）
BR="$(git branch --show-current)"
run "6. 合并远端分支" T6 sh -c 'git merge --ff-only "origin/${BR}" || git reset --soft "origin/${BR}"'

# 7. 收缩 reflog 并 gc
run "7. 收缩 reflog+gc" T7 sh -c 'git reflog expire --expire=now --all && git gc --prune=now'

# 8. 恢复本地改动（若有 stash）
run "8. 恢复本地改动" T8 sh -c 'git stash list | grep -q slim-backup && git stash pop || true'

# 9. 核对工作区并输出体积对比
run "9. 核对工作区" T9a git status --porcelain
run "9. 输出体积对比" T9b du -sh .git

# 耗时汇总
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
