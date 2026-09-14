#!/usr/bin/env bash
# baseline-smoke.sh —— select-baseline.mjs 回归冒烟（临时仓库，不落任何 fixture 到本仓库）。
#
# 用法：bash scripts/tests/baseline-smoke.sh
# 覆盖：稳定 tag 优先 / 预发布与移动 tag 排除 / 稳定分支兜底 / 多包 tag 歧义 / 陈旧 tag 拦截 /
#       无 main/master 兜底矩阵 / 特性分支不当主干 / 脏工作树不静默覆盖 / 远端模式(file://) / --ref 指定与校验。
# 退出码：0 = 全部通过；1 = 有断言失败。

set -u
SEL="$(cd "$(dirname "$0")/.." && pwd)/select-baseline.mjs"
S="$(mktemp -d "${TMPDIR:-/tmp}/pi-baseline.XXXXXX")"
trap 'rm -rf "$S"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fail=0

mk() { # mk <dir> <branch>
  mkdir -p "$1" && git -C "$1" init -q -b "$2"
  echo a >"$1/f.txt" && git -C "$1" add -A && git -C "$1" commit -qm init
}
assert() { # assert <描述> <期望子串> <实际输出>
  if grep -qF "$2" <<<"$3"; then echo "  PASS $1"; else echo "  FAIL $1（期望含：$2）"; echo "$3" | sed 's/^/    | /'; fail=1; fi
}

echo "1) 稳定 tag 优先，排除预发布/移动 tag"
mk "$S/t" develop
git -C "$S/t" tag v1.0.0 && git -C "$S/t" tag v1.1.0-rc1 && git -C "$S/t" tag latest
git -C "$S/t" branch release/1.x && git -C "$S/t" branch feat/x
out=$(node "$SEL" "$S/t"); assert "选中 v1.0.0" "选定基线：v1.0.0" "$out"
assert "状态为 TAG" "[BASELINE-TAG]" "$out"

echo "2) 只有预发布 tag → 落到稳定分支"
mk "$S/b" develop
git -C "$S/b" tag v2.0.0-beta.1 && git -C "$S/b" branch release/2.0
assert "选中 release/2.0" "选定基线：release/2.0" "$(node "$SEL" "$S/b")"

echo "3) 多包 tag 判歧义；--package 消歧"
mk "$S/m" develop
git -C "$S/m" tag core@1.0.0 && git -C "$S/m" tag sdk@2.0.0
assert "歧义" "[BASELINE-AMBIGUOUS]" "$(node "$SEL" "$S/m" 2>&1)"
assert "消歧后选中 core@1.0.0" "选定基线：core@1.0.0" "$(node "$SEL" "$S/m" --package core)"

echo "4) 陈旧 tag 需确认（退码 2）"
mk "$S/s" main
git -C "$S/s" tag v1.0.0 && echo b >"$S/s/g.txt" && git -C "$S/s" add -A && git -C "$S/s" commit -qm second
assert "标记陈旧" "[BASELINE-STALE]" "$(node "$SEL" "$S/s" --stale-commits 0)"
node "$SEL" "$S/s" --stale-commits 0 >/dev/null; [ "$?" -eq 2 ] && echo "  PASS 陈旧退码 2" || { echo "  FAIL 陈旧退码应为 2"; fail=1; }

echo "5) 无 main/master 兜底矩阵（默认分支 develop）"
mk "$S/d" develop
out=$(node "$SEL" "$S/d"); assert "兜底选 develop" "选定基线：develop" "$out"
assert "状态为 FALLBACK" "[BASELINE-FALLBACK]" "$out"

echo "6) 只有特性分支时不得把特性分支当主干"
mk "$S/f" develop
git -C "$S/f" checkout -qb feat/only && echo b >"$S/f/g.txt" && git -C "$S/f" add -A && git -C "$S/f" commit -qm feat
assert "仍选 develop" "选定基线：develop" "$(git -C "$S/f" checkout -q develop; node "$SEL" "$S/f")"

echo "7) 脏工作树不静默覆盖"
mk "$S/c" main
echo dirty >>"$S/c/f.txt"
assert "给 worktree 建议" "worktree add" "$(node "$SEL" "$S/c")"

echo "8) 远端模式（file:// 不当作本地路径）"
mk "$S/r" develop
git -C "$S/r" tag v3.1.4
assert "远端选中 v3.1.4" "选定基线：v3.1.4" "$(node "$SEL" "file://$S/r")"
assert "给出 clone --branch" "git clone --branch v3.1.4" "$(node "$SEL" "file://$S/r")"

echo "9) --ref 指定与校验"
assert "--ref 生效" "[BASELINE-USER]" "$(node "$SEL" "$S/t" --ref v1.1.0-rc1)"
assert "--ref 不存在则拦截" "[BASELINE-UNVERIFIED]" "$(node "$SEL" "$S/t" --ref nope/nope 2>&1)"

echo
[ "$fail" -eq 0 ] && echo "全部通过" || echo "存在失败断言"
exit "$fail"
