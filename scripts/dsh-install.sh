#!/usr/bin/env bash
# dsh 接入安装脚本（幂等，可重复执行）：
#   1) 把 ai-kit/skills/* 软链到 dsh 用户技能目录（$DSH_HOME/skills，默认 ~/.dsh/skills）
#   2) 把 commands-dsh 插件注册进 dsh profile（默认 web）
# 卸载：dsh plugin --profile web remove dsh-git-commands（bundles 会自动摘除），并删除对应软链。
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
DSH_PROFILE="${DSH_PROFILE:-web}"

echo "==> ai-kit 根目录: $REPO_ROOT"
echo "==> dsh profile:  $DSH_PROFILE"

# 1) skills -> $DSH_HOME_DIR/skills
SKILLS_TARGET="$DSH_HOME_DIR/skills"
mkdir -p "$SKILLS_TARGET"

# 1.0) 清理残留软链：指向本仓库 skills/ 下已不存在目录（如 skill 重命名后）的悬空软链
removed=0
for target in "$SKILLS_TARGET"/*; do
  [ -L "$target" ] || continue
  real="$(readlink "$target")"
  case "$real" in
    "$REPO_ROOT"/skills/*)
      if [ ! -d "$real" ]; then
        rm "$target"
        echo "清理悬空软链: $target -> $real（目标目录已不存在）"
        removed=$((removed + 1))
      fi
      ;;
  esac
done
[ "$removed" -gt 0 ] && echo "==> 已清理 $removed 个残留软链"

linked=0
for skill_dir in "$REPO_ROOT"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_TARGET/$skill_name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "跳过：$target 已存在且是真实目录（不覆盖）"
    continue
  fi
  ln -sfn "$skill_dir" "$target"
  linked=$((linked + 1))
done
echo "==> skills 软链完成（$linked 个）-> $SKILLS_TARGET"

# 2) 注册插件到 profile（link: 真软链，保证源码改动与运行时定位都指向 ai-kit 本体）
if ! command -v dsh >/dev/null 2>&1; then
  echo "错误：未找到 dsh 命令，请先安装 @deepseek-ai/dsh" >&2
  exit 1
fi
dsh plugin --profile "$DSH_PROFILE" add "link:${REPO_ROOT}/commands-dsh"

cat <<'DONE'

完成。请重启 dsh web 使新命令生效：
  停掉当前 dsh web 进程后重新运行 dsh web

验证（重启前可先离线检查配置树是否含插件行）：
  dsh --profile web --dump-config | grep -A2 dsh-git-commands
DONE
