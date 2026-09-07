#!/usr/bin/env bash
# 供 changesets/action 的 publish 命令调用（action 用 @actions/exec 执行单一命令，不做 shell 解析，
# 所以必须是 `bash <此脚本>` 这种单命令，逻辑都放在本脚本里）。
# 目标：把 commands-dsh 按当前 package.json 版本发布到 npmjs；若该版本已发布则跳过。
set -euo pipefail

cd "$(dirname "$0")/.."   # 仓库根
cd commands-dsh

name="@morehao/dsh-commands"
v="$(node -p "require('./package.json').version")"

echo "Publish check: ${name}@${v}"

published="$(npm view "${name}@${v}" version --registry https://registry.npmjs.org 2>/dev/null || true)"
if [ -n "$published" ]; then
  echo "${name}@${v} already published on npmjs; skip"
  exit 0
fi

echo "Publishing ${name}@${v}"
# OIDC 可信发布：job 提 id-token: write，npm CLI(>=11.5.1) 自动换取短时令牌，无需 NODE_AUTH_TOKEN。
npm publish --provenance --access public --registry https://registry.npmjs.org
