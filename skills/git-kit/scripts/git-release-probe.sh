#!/usr/bin/env bash
# git-release-probe.sh —— git-kit「release 分支」的发版前**只读探测**（单一真源）。
#
# 只报告事实，不修改任何文件、不创建 tag、不写 git 状态。release 流程据此让用户
# 确认版本号与版本文件，再执行「升版本 → 提交 → 打 tag → 推送 → 验证」。
#
# 用法:
#   bash <skill基目录>/scripts/git-release-probe.sh [目标仓库]
#     目标仓库缺省时优先 upstream、回退 origin（与 pr-create/pr-merge 一致）。
#     可在任意目录调用：脚本自行切到 git 仓库根后再探测（版本文件与工作流均为
#     CWD 相对，故必须先定位仓库根，否则子目录调用会漏探测）。
#
# 退出码: 0 = 探测完成（部分事实可为空）；1 = 不在 git 仓库内或用法错误。
set -uo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	sed -n '2,13p' "$0"
	exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "ERROR: 当前目录不是 git 仓库" >&2
	exit 1
fi

# 版本文件、包元数据、CI 工作流探测全部是 CWD 相对，统一切到仓库根。
cd "$(git rev-parse --show-toplevel)" || exit 1

REMOTE="${1:-}"
if [ -z "$REMOTE" ]; then
	for r in upstream origin; do
		if git remote get-url "$r" >/dev/null 2>&1; then
			REMOTE="$r"
			break
		fi
	done
fi

echo "== repo =="
echo "REMOTE=${REMOTE:-<none>}"
[ -n "$REMOTE" ] && echo "REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null)"
echo "BRANCH=$(git branch --show-current 2>/dev/null)"
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
	echo "DIRTY=no"
else
	echo "DIRTY=yes"
fi

# ---------- 最新 tag 与下一版本候选 ----------
LATEST_TAG="$(git tag --sort=-v:refname 2>/dev/null | head -n1)"
if [ -z "$LATEST_TAG" ]; then
	LATEST_TAG="$(git tag --sort=-creatordate 2>/dev/null | head -n1)"
fi
echo "LATEST_TAG=${LATEST_TAG:-<none>}"

# semver 递增：v1.2.3 -> vX.Y.Z 三档候选（沿用现有前缀风格）
if [ -n "$LATEST_TAG" ]; then
	plain="${LATEST_TAG#v}"
	case "$plain" in
	*.*.*)
		major="${plain%%.*}"
		rest="${plain#*.}"
		minor="${rest%%.*}"
		patch="${rest#*.}"
		case "$major$minor$patch" in
		*[!0-9]*) ;; # 含非数字（如 1.2.3-rc1）：不猜，留给用户自定义
		*)
			if [ "${LATEST_TAG#v}" != "$LATEST_TAG" ]; then
				echo "TAG_PREFIX=v"
				echo "NEXT=v$major.$minor.$((patch + 1)) v$major.$((minor + 1)).0 v$((major + 1)).0.0"
			else
				echo "TAG_PREFIX=<none>"
				echo "NEXT=$major.$minor.$((patch + 1)) $major.$((minor + 1)).0 $((major + 1)).0.0"
			fi
			;;
		esac
		;;
	*) echo "NOTE=最新 tag 非 semver，候选版本号需用户自定义" ;;
	esac
else
	echo "TAG_PREFIX=v"
	echo "NOTE=仓库尚无 tag，候选（首个版本）: v0.1.0 v1.0.0"
	echo "NEXT=v0.1.0 v1.0.0"
fi

# ---------- 版本文件探测（package.json 含 workspace 子包） ----------
PKG_FILES=()
PKG_VALUES=()

read_pkg_version() {
	# 输出 package.json 的顶层 version；读不到输出空
	local f="$1" v=""
	if command -v node >/dev/null 2>&1; then
		v="$(node -e 'try{const p=require(process.argv[1]);process.stdout.write(String(p.version||""))}catch(e){}' "./$f" 2>/dev/null)"
	fi
	if [ -z "$v" ]; then
		v="$(grep -m1 -E '^[[:space:]]*"version"[[:space:]]*:' "$f" 2>/dev/null |
			sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
	fi
	printf '%s' "$v"
}

add_pkg_file() {
	local f="$1" v
	[ -f "$f" ] || return 0
	for existing in ${PKG_FILES[@]+"${PKG_FILES[@]}"}; do
		[ "$existing" = "$f" ] && return 0
	done
	v="$(read_pkg_version "$f")"
	PKG_FILES+=("$f")
	PKG_VALUES+=("$v")
}

# workspace 子包目录：pnpm-workspace.yaml 的 packages 列表 + package.json 的 workspaces 数组
WS_DIRS=()
if [ -f pnpm-workspace.yaml ]; then
	while IFS= read -r d; do
		[ -n "$d" ] && WS_DIRS+=("$d")
	done < <(awk '
		/^packages:/ { inblock = 1; next }
		/^[a-zA-Z]/ { inblock = 0 }
		inblock && /^[[:space:]]*-[[:space:]]*/ {
			line = $0
			sub(/^[[:space:]]*-[[:space:]]*/, "", line)
			gsub(/["'"'"']/, "", line)
			gsub(/[[:space:]]*#.*/, "", line)
			if (line != "") print line
		}
	' pnpm-workspace.yaml)
fi
if [ -f package.json ] && command -v node >/dev/null 2>&1; then
	while IFS= read -r d; do
		[ -n "$d" ] && WS_DIRS+=("$d")
	done < <(node -e '
		try {
			const p = require("./package.json");
			const ws = p.workspaces;
			const list = Array.isArray(ws) ? ws : (ws && Array.isArray(ws.packages) ? ws.packages : []);
			for (const d of list) console.log(d);
		} catch (e) {}
	' 2>/dev/null)
fi

add_pkg_file package.json
for d in ${WS_DIRS[@]+"${WS_DIRS[@]}"}; do
	# 支持 workspaces 通配（如 packages/*）
	for expanded in $d; do
		[ -d "$expanded" ] && add_pkg_file "$expanded/package.json"
	done
done

# 其他生态的版本载体（每类取第一个命中）
first_of() { for f in "$@"; do [ -f "$f" ] && { printf '%s' "$f"; return 0; }; done; }

toml_version() {
	# "$1" = 文件; "$2" = 以空格分隔的可接受 section 名（含方括号，如 "[project] [tool.poetry]"）
	# 注意：不要用正则匹配 section（awk -v 会吞掉反斜杠转义），用精确字符串比对。
	awk -v sections="$2" '
		/^[[:space:]]*\[/ {
			sect = $0
			sub(/[[:space:]]*#.*/, "", sect)
			gsub(/[[:space:]]/, "", sect)
			next
		}
		index(" " sections " ", " " sect " ") > 0 && /^[[:space:]]*version[[:space:]]*=/ {
			line = $0
			sub(/[[:space:]]+#.*/, "", line)   # 去行尾注释（如 version = "1.2.3"  # bump）
			sub(/^[^=]*=[[:space:]]*/, "", line)
			gsub(/["'"'"'[:space:]]/, "", line)
			if (line != "") {
				print line
				exit
			}
		}
	' "$1"
}

OTHER_FILES=()
OTHER_VALUES=()
if [ -f pyproject.toml ]; then
	OTHER_FILES+=("pyproject.toml")
	OTHER_VALUES+=("$(toml_version pyproject.toml "[project] [tool.poetry]")")
fi
if [ -f Cargo.toml ]; then
	OTHER_FILES+=("Cargo.toml")
	OTHER_VALUES+=("$(toml_version Cargo.toml "[package] [workspace.package]")")
fi
for vf in VERSION version.txt version; do
	if [ -f "$vf" ]; then
		OTHER_FILES+=("$vf")
		OTHER_VALUES+=("$(head -n1 "$vf" | tr -d '[:space:]')")
		break
	fi
done

echo "== version files =="
if [ ${#PKG_FILES[@]} -eq 0 ] && [ ${#OTHER_FILES[@]} -eq 0 ]; then
	echo "FILE=<none>"
	echo "NOTE=未探测到版本文件（release 流程需用户指定版本载体与版本号）"
else
	i=0
	while [ $i -lt ${#PKG_FILES[@]} ]; do
		echo "FILE	${PKG_FILES[$i]}	${PKG_VALUES[$i]:-<no-version>}"
		i=$((i + 1))
	done
	i=0
	while [ $i -lt ${#OTHER_FILES[@]} ]; do
		echo "FILE	${OTHER_FILES[$i]}	${OTHER_VALUES[$i]:-<no-version>}"
		i=$((i + 1))
	done
	# 一致性：所有**可读到的**版本值相同才算一致（不一致必须让用户裁决基准）
	# `<no-version>`（如 private 根 package.json 无 version 字段）不参与判定。
	UNIQ="$(printf '%s\n' ${PKG_VALUES[@]+"${PKG_VALUES[@]}"} ${OTHER_VALUES[@]+"${OTHER_VALUES[@]}"} |
		grep -v '^$' | sort -u | wc -l | tr -d '[:space:]')"
	case "$UNIQ" in
	0 | 1) echo "VERSION_CONSISTENT=yes" ;;
	*) echo "VERSION_CONSISTENT=no" ;;
	esac
fi

# ---------- npm 发布面（用于发版后验证） ----------
if [ -f package.json ] && command -v node >/dev/null 2>&1; then
	echo "== npm =="
	node -e '
		try {
			const p = require("./package.json");
			console.log("NPM_PACKAGE=" + (p.name || "<none>"));
			console.log("NPM_PRIVATE=" + (p.private ? "yes" : "no"));
		} catch (e) {}
	' 2>/dev/null
fi

# ---------- tag 触发的 CI workflow（发版后验证入口） ----------
if [ -d .github/workflows ]; then
	echo "== tag-triggered workflows =="
	found=0
	for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
		[ -f "$wf" ] || continue
		pattern="$(awk '
			/^[[:space:]]*tags:/ { intags = 1; next }
			intags && /^[[:space:]]*-[[:space:]]*/ {
				line = $0
				sub(/^[[:space:]]*-[[:space:]]*/, "", line)
				gsub(/["'"'"']/, "", line)
				printf "%s ", line
				next
			}
			intags && /^[[:space:]]*[a-zA-Z]/ { intags = 0 }
		' "$wf")"
		if [ -n "$pattern" ]; then
			echo "WORKFLOW	$wf	$pattern"
			found=1
		fi
	done
	[ "$found" -eq 0 ] && echo "WORKFLOW=<none>"
fi

exit 0
