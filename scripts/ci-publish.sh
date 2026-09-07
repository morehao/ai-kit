#!/usr/bin/env bash
# tag 触发发布（git tag vX.Y.Z -> 发布 @morehao/dsh-commands@X.Y.Z，经 OIDC）。
# 由 .github/workflows/release.yml 的 publish 步骤调用（action 用 @actions/exec 执行单一命令，
# 不做 shell 解析，所以是 `bash <此脚本>` 这种单命令，逻辑都在本脚本里）。
set -euo pipefail

# 从 CI 传入的 tag（如 v1.2.3）取版本；本地跑可用 RELEASE_TAG=... 或 GIT_TAG=vX.Y.Z。
TAG="${RELEASE_TAG:-${GIT_TAG:-}}"
if [ -z "$TAG" ]; then
  echo "错误：未设置 RELEASE_TAG（应为 push 的 tag，如 v1.2.3）" >&2
  exit 1
fi
PKG_VERSION="${TAG#v}"   # v1.2.3 -> 1.2.3

# 仓库根 + commands-dsh 目录
cd "$(dirname "$0")/.."
PKG_DIR="commands-dsh"
cd "$PKG_DIR"

name="@morehao/dsh-commands"
PKG_JSON_VERSION="$(node -p "require('./package.json').version")"

echo "Publish check: ${name}@${PKG_JSON_VERSION} (tag=${TAG})"

# 1) tag 版本必须与 package.json 版本一致，避免误发。
if [ "$PKG_JSON_VERSION" != "$PKG_VERSION" ]; then
  echo "错误：tag 版本 ${PKG_VERSION} 与 package.json 版本 ${PKG_JSON_VERSION} 不一致，拒绝发布" >&2
  exit 1
fi

# 2) 该版本已发布则跳过（幂等）。
published="$(npm view "${name}@${PKG_VERSION}" version --registry https://registry.npmjs.org 2>/dev/null || true)"
if [ -n "$published" ]; then
  echo "${name}@${PKG_VERSION} already published on npmjs; skip"
  exit 0
fi

# 3) OIDC 可信发布：job 提 id-token: write，npm CLI(>=11.5.1) 自动换取短时令牌，无需 NODE_AUTH_TOKEN。
echo "Publishing ${name}@${PKG_VERSION}"
npm publish --provenance --access public --registry https://registry.npmjs.org
