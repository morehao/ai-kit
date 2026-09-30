#!/usr/bin/env bash
# dsh 接入安装脚本（幂等，可重复执行）：
#   1) 把 ai-kit/skills/* 软链到 dsh 用户技能目录（$DSH_HOME/skills，默认 ~/.dsh/skills，全局生效）
#   2) 把 commands-dsh 插件注册进 dsh profile
#
# 用法：./scripts/dsh-install.sh [--profile <name>] [--skills-only] [--npm]
#
#   --profile <name>   dsh profile 名。默认取 $DSH_PROFILE；未设置时，若 $DSH_HOME/profiles
#                      下只有一个 profile 就自动选用它，多个或零个则报错要求显式指定。
#                      （早期版本硬编码 web，与实际安装不符时会凭空造出一个 profile，已修。）
#   --skills-only      只做第 1 步（软链 skills），跳过插件注册；不需要 dsh CLI，也不碰 profile。
#   --npm              第 2 步装已发布的 npm 包 @morehao/dsh-commands，而非本地 link:（等价 DSH_USE_NPM=1）。
#   -h, --help         显示帮助。
#
# 环境变量：
#   DSH_HOME      dsh 配置根，默认 ~/.dsh
#   DSH_PROFILE   默认 profile 名
#   DSH_USE_NPM   =1 等价 --npm
#
# 本脚本默认是「开发/本地接入」方式（link: 真软链，源码改动即生效；改插件 lib/index.js 需重启 dsh）。
# 技能软链是热加载的：新增后 dsh 立即看到，不需要重启。
#
# 卸载：dsh plugin --profile <profile> remove @morehao/dsh-commands（bundles 会自动摘除），
#       并删除对应软链（rm "$DSH_HOME/skills/<name>"）。
# 注意：插件名现在是 scoped 的 @morehao/dsh-commands；若你旧版以 dsh-git-commands 或
#   @morehao/dsh-git-commands 安装过，脚本会自动先移除旧名再重装，避免新旧 bundle 并存。
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PROFILES_DIR="$DSH_HOME_DIR/profiles"
PROFILE="${DSH_PROFILE:-}"
SKILLS_ONLY=0
USE_NPM="${DSH_USE_NPM:-0}"

usage() {
  cat <<'EOF'
用法: ./scripts/dsh-install.sh [选项]

  --profile <name>   dsh profile 名。默认取 $DSH_PROFILE；未设置时，若 $DSH_HOME/profiles
                     下只有一个 profile 就自动选用它，多个或零个则报错要求显式指定。
  --skills-only      只软链 skills 到 $DSH_HOME/skills，跳过插件注册（不需要 dsh CLI）。
  --npm              插件装已发布的 @morehao/dsh-commands，而非本地 link:（等价 DSH_USE_NPM=1）。
  -h, --help         显示本帮助。

环境变量:
  DSH_HOME      dsh 配置根，默认 ~/.dsh
  DSH_PROFILE   默认 profile 名
  DSH_USE_NPM   =1 等价 --npm

示例:
  ./scripts/dsh-install.sh --skills-only              # 只挂技能，最常用的安全子集
  ./scripts/dsh-install.sh --profile desktop          # 指定 profile 全量接入
  DSH_USE_NPM=1 ./scripts/dsh-install.sh              # 插件走 npm 已发布包
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      if [ $# -lt 2 ]; then
        echo "错误：--profile 需要一个参数" >&2
        exit 2
      fi
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
      shift
      ;;
    --skills-only)
      SKILLS_ONLY=1
      shift
      ;;
    --npm)
      USE_NPM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "错误：未知参数 $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# 列出已有 profile 名（每行一个）；无匹配时无输出（不用 nullglob，保持 bash 3.2 兼容）
existing_profiles() {
  local d
  for d in "$PROFILES_DIR"/*/; do
    [ -d "$d" ] || continue
    basename "$d"
  done
}

# 解析 PROFILE：显式指定（--profile / DSH_PROFILE）优先，否则在「唯一 profile」时自动选用
resolve_profile() {
  local d names n
  if [ -n "$PROFILE" ]; then
    return 0
  fi
  names=""
  n=0
  for d in "$PROFILES_DIR"/*/; do
    [ -d "$d" ] || continue
    names="$names $(basename "$d")"
    n=$((n + 1))
  done
  if [ "$n" -eq 1 ]; then
    PROFILE="${names# }"
    echo "==> 未指定 profile，自动选用唯一存在的 profile: $PROFILE"
    return 0
  fi
  if [ "$n" -eq 0 ]; then
    echo "错误：$PROFILES_DIR 下没有任何 profile，无法注册插件。" >&2
    echo "  请先启动一次 dsh 客户端以生成 profile，或用 --skills-only 只软链技能。" >&2
    return 1
  fi
  echo "错误：$PROFILES_DIR 下有多个 profile，请用 --profile <name> 或 DSH_PROFILE=<name> 指定：" >&2
  for d in "$PROFILES_DIR"/*/; do
    [ -d "$d" ] || continue
    echo "  - $(basename "$d")" >&2
  done
  return 1
}

# 定位 dsh CLI：PATH 优先，其次 macOS 桌面版 app 包内的 CLI
find_dsh() {
  local c
  if command -v dsh >/dev/null 2>&1; then
    command -v dsh
    return 0
  fi
  for c in \
    "/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh" \
    "$HOME/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh"; do
    if [ -x "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

echo "==> ai-kit 根目录: $REPO_ROOT"
echo "==> dsh 配置根:  $DSH_HOME_DIR"

# ---------- 1) skills -> $DSH_HOME_DIR/skills ----------
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
        echo "清理悬空软链: ${target} -> ${real}（目标目录已不存在）"
        removed=$((removed + 1))
      fi
      ;;
  esac
done
if [ "$removed" -gt 0 ]; then
  echo "==> 已清理 $removed 个残留软链"
fi

linked=0
skipped=0
for skill_dir in "$REPO_ROOT"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_dir="${skill_dir%/}"   # 去掉 glob 带来的尾部斜杠，让软链目标干净可比对
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_TARGET/$skill_name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "跳过：$target 已存在且是真实目录（不覆盖）"
    skipped=$((skipped + 1))
    continue
  fi
  ln -sfn "$skill_dir" "$target"
  linked=$((linked + 1))
done
echo "==> skills 软链完成（新建/更新 $linked 个，跳过 $skipped 个）-> $SKILLS_TARGET"

if [ "$SKILLS_ONLY" -eq 1 ]; then
  cat <<DONE

完成（--skills-only）。技能已软链到：
  $SKILLS_TARGET
dsh 对技能是热加载的，无需重启即可在会话与技能面板中看到。
插件注册已按要求跳过；需要时去掉 --skills-only 重跑本脚本。
DONE
  exit 0
fi

# ---------- 2) 注册插件到 profile ----------
if ! resolve_profile; then
  echo "  提示：技能软链（第 1 步）已完成，只是插件注册（第 2 步）未执行。" >&2
  exit 2
fi

# 2.1) profile 必须是已存在的，避免 dsh 为你凭空创建（这正是早期硬编码 web 的坑）
if [ ! -d "$PROFILES_DIR/$PROFILE" ]; then
  echo "错误：profile「${PROFILE}」不存在：$PROFILES_DIR/$PROFILE" >&2
  echo "  已有 profile：" >&2
  existing_profiles | sed 's/^/    - /' >&2
  echo "  若确实要新建 profile，请直接用: dsh plugin --profile $PROFILE add ..." >&2
  exit 2
fi
echo "==> dsh profile:  $PROFILE"

if ! DSH_BIN="$(find_dsh)"; then
  DSH_BIN=""
fi
if [ -z "$DSH_BIN" ]; then
  echo "错误：未找到 dsh 命令。" >&2
  echo "  skills 软链（第 1 步）已完成；仅插件注册（第 2 步）未执行。" >&2
  echo "  若插件早已装好，用 --skills-only 即可跳过本步；否则请把 dsh 加入 PATH 后重跑。" >&2
  exit 1
fi
case "$DSH_BIN" in
  */runtime/cli/bin/dsh)
    echo "==> 使用客户端内置 CLI: $DSH_BIN"
    echo "    注意：这是 dsh 客户端自带的 CLI。若客户端正在运行，建议先退出再执行本步，"
    echo "    避免两边并发改写 profile 配置；只想让技能生效请改跑 --skills-only。"
    ;;
  *)
    echo "==> 使用 PATH 上的 dsh: $DSH_BIN"
    ;;
esac

# 2.2) 旧名迁移：若 profile 里还挂着旧名（dsh-git-commands / @morehao/dsh-git-commands），先移除，
#      避免与新 scoped 名并存导致 cordis 重复注册（同一 id 冲突）。
OLD_PROFILE_PKG="$PROFILES_DIR/$PROFILE/package.json"
for old_name in "dsh-git-commands" "@morehao/dsh-git-commands"; do
  if [ -f "$OLD_PROFILE_PKG" ] && grep -q "\"$old_name\"" "$OLD_PROFILE_PKG"; then
    echo "==> 检测到旧安装名 ${old_name}，先移除"
    "$DSH_BIN" plugin --profile "$PROFILE" remove "$old_name" || true
  fi
done

if [ "$USE_NPM" = "1" ]; then
  echo "==> 安装已发布 npm 包 @morehao/dsh-commands（skills 仍由本仓库软链提供）"
  "$DSH_BIN" plugin --profile "$PROFILE" add "@morehao/dsh-commands"
else
  echo "==> 安装开发 link: $REPO_ROOT/commands-dsh"
  "$DSH_BIN" plugin --profile "$PROFILE" add "link:$REPO_ROOT/commands-dsh"
fi

cat <<DONE

完成。profile: $PROFILE

请重启 dsh 使新命令生效（技能软链是热加载的，不需要重启，只有插件改动才需要）。
验证（重启前可先离线检查配置树是否含插件行）：
  dsh --profile $PROFILE --dump-config | grep -A2 @morehao/dsh-commands

只软链技能、不碰插件：
  ./scripts/dsh-install.sh --skills-only
DONE
