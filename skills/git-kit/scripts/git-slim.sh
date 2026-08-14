#!/usr/bin/env bash
# git-slim.sh —— 将当前目录的 git 仓库瘦身为浅克隆
# 默认保留最近 30 天历史；传 `$1` 数字则以天为单位（git-slim.sh 90 = 保留 90 天）
# 最高优先级：绝不丢失任何本地未提交改动。
# 每步记录开始时刻与耗时，结束后输出各步骤耗时汇总；任一步失败会立即中止并带出失败步骤+累计耗时。
#
# 设计约束（实战教训）：
# - 面向"只分析、永不提交"的仓库：本地删除旧 tag 与远端跟踪引用是安全的，可彻底瘦身。
# - gc 顺序必须是 清引用/tag -> reflog expire -> git gc --prune=now（非 aggressive）。
#   若在删除前跑 --aggressive，会在含大量对象(数万+)时跑几十分钟甚至超时。
set -e

echo "[$(date '+%H:%M:%S')] -> 0. 注入计时与失败捕获机制"

TOTAL_START=$(date +%s)
RUN_STEP=
# 各步骤耗时占位变量
T2= T3= T5= T6= T6a= T6b= T7= T8= T9a= T9b=

# 兜底：任何未被 run 捕获的异常退出时，若仍处于某步骤，则打印失败信息
trap 'if [ -n "$RUN_STEP" ]; then
  echo "[兜底中止] 失败于: $RUN_STEP, 累计耗时 $(( $(date +%s) - TOTAL_START ))s" >&2
fi' EXIT

run() {
  local __step="$1" __var="$2" __s __code; shift 2
  RUN_STEP="$__step"
  echo "[$(date '+%H:%M:%S')] -> $__step"
  __s=$(date +%s)
  "$@" && __code=0 || __code=$?   # 吸收失败，避免 set -e 直接跳过函数体
  if [ $__code -ne 0 ]; then
    RUN_STEP=
    echo "[中止] 失败于: $__step, 累计耗时 $(( $(date +%s) - TOTAL_START ))s" >&2
    exit $__code
  fi
  eval "$__var=\$(( $(date +%s) - __s ))"
  printf '  [完成 %s, 耗时 %ss / 累计 %ss]\n' "$__step" "$(( $(date +%s) - __s ))" "$(( $(date +%s) - TOTAL_START ))"
  RUN_STEP=
}

# 参数：保留天数（默认 30）
if [[ "$1" =~ ^[0-9]+$ ]]; then N="$1"; else N=30; fi
DEPTH="$N days ago"
CUTOFF_UNIX=$(( $(date +%s) - N * 86400 ))

# 1. 前置安全校验（自提交检测）：仓库存在作者/提交者为当前 git 用户本人的提交则中止
name="$(git config user.name)"; email="$(git config user.email)"
if [ -n "$name" ] && git log --all --author="$name" --format='%H' | grep -q .; then
  echo "检测到本人提交（作者=$name），禁止执行本命令" >&2; exit 1
fi
if [ -n "$email" ] && git log --all --committer="$email" --format='%H' | grep -q .; then
  echo "检测到本人提交（提交者=$email），禁止执行本命令" >&2; exit 1
fi

# 2. 记录瘦身前体积与对象规模（写入临时文件，供步骤 9 量化磁盘收益）
SLIM_TMP="/tmp/git-slim-before-$$"
run "2. 记录瘦身前体积" T2 bash -c '
  du -sk .git | awk "{print \$1}" > "'"$SLIM_TMP"'"
  du -sh .git
  git count-objects -v | grep -E "^(in-pack|size-pack):"
'
DU_BEFORE=$(head -1 "$SLIM_TMP" 2>/dev/null)

# 3. 安全检查并缓存改动（git ls-files 用 grep -q 判空，避免 --quiet 非法选项）
run "3. 安全检查与缓存" T3 sh -c '
  git status --porcelain
  if ! git diff --quiet || ! git diff --cached --quiet || git ls-files --others --exclude-standard | grep -q .; then
    git stash push -u -m "slim-backup-$(date +%s)"
  fi
'

# 4. 解析保留深度
echo "[4. 保留深度] $DEPTH"

# 5. 浅拉取
run "5. 浅拉取" T5 git fetch --shallow-since="$DEPTH" --prune origin "$(git branch --show-current)"

BR="$(git branch --show-current)"

# 6. 本地分支对齐远端（不损坏已 stash 改动）
run "6. 合并远端分支" T6 sh -c "git merge --ff-only 'origin/$BR' || git reset --soft 'origin/$BR'"

# 6a. 清理远端跟踪引用：仅保留 origin/<当前分支> 与 origin/HEAD，
#     删除其余 refs/remotes/origin/*（含 packed-refs 中条目），避免它们勾住完整历史。
run "6a. 清理远端跟踪引用" T6a bash -c '
  git for-each-ref "refs/remotes/origin/*" --format="%(refname)" \
    | grep -vE "refs/remotes/origin/('"$BR"'|HEAD)$" \
    | while read -r r; do git update-ref -d "$r"; done
  # 同步删除 packed-refs 中可能残留的条目
  if [ -f .git/packed-refs ]; then
    grep -v " refs/remotes/origin/" .git/packed-refs > .git/packed-refs.tmp \
      && mv .git/packed-refs.tmp .git/packed-refs
  fi
  echo "  剩余远端引用: $(git for-each-ref "refs/remotes/origin/*" --format="%(refname)" | wc -l | tr -d " ")"
'

# 6b. 清理 N 天前创建的 tag（面向只分析仓库，删除是安全的；需要时 git fetch --tags 恢复）
run "6b. 清理旧 tag" T6b bash -c '
  kept=0; removed=0
  while IFS= read -r line; do
    ts="${line%% *}"; tn="${line#* }"
    if [ "$ts" -lt "'"$CUTOFF_UNIX"'" ]; then
      git tag -d "$tn" >/dev/null 2>&1 && removed=$((removed+1))
    else
      kept=$((kept+1))
    fi
  done < <(git for-each-ref --sort=creatordate --format="%(creatordate:unix) %(refname:short)" refs/tags)
  echo "  删除旧 tag: $removed, 保留: $kept"
'

# 7. 收缩 reflog 并 gc（务必在清理引用/tag 之后、用非 aggressive，避免超时）
run "7. 收缩 reflog+gc" T7 sh -c 'git reflog expire --expire=now --all && git gc --prune=now'

# 8. 恢复本地改动（若有 stash）
run "8. 恢复本地改动" T8 sh -c 'git stash list | grep -q slim-backup && git stash pop || true'

# 9. 核对工作区与远端对齐（只核对 head == origin/<BR>，不跑 git pull 以免网络挂起）
run "9. 核对工作区" T9a git status --porcelain
run "9. 核对远端对齐与体积" T9b bash -c '
  local_head=$(git rev-parse HEAD)
  origin_head=$(git rev-parse "refs/remotes/origin/'$BR'" 2>/dev/null || echo MISSING)
  if [ "$local_head" = "$origin_head" ]; then
    echo "  HEAD == origin/'$BR' ($local_head) ✓"
  else
    echo "  [警告] HEAD=$local_head origin/'$BR'=$origin_head" >&2
  fi
  du -sh .git
  git count-objects -v | grep -E "^(in-pack|size-pack):"
'

# 9c. 量化磁盘收益（对比步骤 2 记录的 .git 目录大小差异）
DU_AFTER=$(du -sk .git | awk '{print $1}')
DU_BEFORE=${DU_BEFORE:-0}
SAVED_KB=$(( DU_BEFORE - DU_AFTER ))
echo "==== 磁盘收益对比 ===="
if [ "$SAVED_KB" -le 0 ]; then
  echo "  .git 目录：${DU_BEFORE}KiB -> ${DU_AFTER}KiB (未缩小，仅对齐/清理引用)"
else
  echo "  .git 目录：${DU_BEFORE}KiB -> ${DU_AFTER}KiB"
  if [ $(( SAVED_KB / 1024 )) -ge 1 ]; then
    echo "  释放磁盘  : $(( SAVED_KB / 1024 ))MiB（$(( SAVED_KB ))KiB）"
  else
    echo "  释放磁盘  : ${SAVED_KB}KiB"
  fi
fi
rm -f "$SLIM_TMP"

# 耗时汇总
echo "==== 耗时汇总 ===="
echo "2. 记录瘦身前体积 : ${T2:-0}s"
echo "3. 安全检查与缓存 : ${T3:-0}s"
echo "5. 浅拉取         : ${T5:-0}s"
echo "6. 合并远端分支   : ${T6:-0}s"
echo "6a. 清理远端引用  : ${T6a:-0}s"
echo "6b. 清理旧 tag    : ${T6b:-0}s"
echo "7. 收缩 reflog+gc : ${T7:-0}s"
echo "8. 恢复本地改动   : ${T8:-0}s"
echo "9. 核对工作区     : ${T9a:-0}s"
echo "9. 核对远端对齐   : ${T9b:-0}s"
echo "总耗时           : $(( $(date +%s) - TOTAL_START ))s"
