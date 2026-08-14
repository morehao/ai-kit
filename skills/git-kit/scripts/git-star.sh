#!/usr/bin/env bash
#
# git-star.sh —— 拉取你在 GitHub 上 star 的所有仓库,按预设大类规则自动打标分类,
# 输出一份 Markdown 清单,方便照着清单手动把仓库拖进对应的 GitHub List。
#
# 优先使用 gh CLI(免管理 token);未安装/未登录 gh 时自动回退到 curl + Personal Access Token。
#
# 依赖:
#   jq                          (必需)
#   gh   (GitHub CLI)           (可选,优先使用,https://cli.github.com)
#   curl                        (gh 不可用时的回退方案)
#
# 用法:
#   # 有 gh 的情况(推荐):
#   gh auth login
#   ./git-star.sh
#
#   # 没有 gh 的情况,用 token:
#   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
#   ./git-star.sh
#
#   # 指定输出文件名 / 显式传 token:
#   ./git-star.sh -o my_stars.md -t ghp_xxxxxxxxxxxx
set -euo pipefail

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
API_ROOT="https://api.github.com"
OUT_FILE="stars_classified.md"
TOKEN="${GITHUB_TOKEN:-}"

while getopts "o:t:h" opt; do
  case "$opt" in
    o) OUT_FILE="$OPTARG" ;;
    t) TOKEN="$OPTARG" ;;
    h)
      echo "用法: git-star.sh [-o 输出文件名] [-t GITHUB_TOKEN]"
      exit 0
      ;;
    *) exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "缺少依赖: jq" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 判断拉取方式:优先 gh CLI,其次 curl + token
# ---------------------------------------------------------------------------
USE_GH=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH=1
  echo "检测到已登录的 gh CLI,使用 gh api 拉取数据。"
elif command -v gh >/dev/null 2>&1; then
  echo "检测到 gh CLI 但尚未登录,可运行 gh auth login 后获得更简便的体验。"
  echo "本次将回退到 curl + token 方式。"
fi

if [[ "$USE_GH" -eq 0 ]]; then
  command -v curl >/dev/null 2>&1 || { echo "缺少依赖: curl" >&2; exit 1; }
  if [[ -z "$TOKEN" ]]; then
    echo "未安装/未登录 gh,且未提供 GitHub token。" >&2
    echo "请二选一:" >&2
    echo "  1) 安装并登录 gh: https://cli.github.com , 然后 gh auth login" >&2
    echo "  2) 提供 token: -t 参数,或设置环境变量 GITHUB_TOKEN" >&2
    echo "     创建 token: https://github.com/settings/tokens (勾选 public_repo / read:user 即可)" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 分类规则: "大类:正则关键词(用 | 分隔,大小写不敏感)"
# 会匹配 topics / language / repo 名 / description 拼接后的字符串
# 按顺序匹配,命中第一个就归入该类;都不命中则归入 uncategorized
# ---------------------------------------------------------------------------
RULES=(
  "ai-ml:machine-learning|deep-learning|neural-network|pytorch|tensorflow|transformer|diffusion|computer-vision|\bnlp\b|reinforcement-learning|\bml\b|\bai\b|onnx|\bjax\b"
  "llm-tools:\bllm\b|\bgpt\b|chatgpt|langchain|\bagent\b|\brag\b|prompt-engineering|openai|anthropic|claude|llama|vector-database|embeddings"
  "frontend:\breact\b|\bvue\b|angular|svelte|frontend|\bcss\b|\bsass\b|webpack|\bvite\b|tailwindcss|nextjs|nuxt"
  "backend:backend|\bapi\b|rest-api|graphql|microservice|django|flask|fastapi|express|spring-boot|nestjs|\bgrpc\b"
  "mobile:android|\bios\b|flutter|react-native|swift|kotlin-android|mobile-app"
  "languages:golang|\brust\b|\bpython\b|typescript|javascript|\bjava\b|\bcpp\b|c-plus-plus|\bruby\b|\bphp\b|\bscala\b|haskell|elixir|language-learning"
  "databases:database|\bsql\b|postgresql|mysql|mongodb|\bredis\b|\borm\b|sqlite|elasticsearch|clickhouse|nosql"
  "data-science:data-science|pandas|numpy|jupyter-notebook|data-analysis|data-visualization|\betl\b"
  "devops:docker|kubernetes|\bk8s\b|ci-cd|\bhelm\b|devops|container|\bargo\b|jenkins|github-actions"
  "cloud-infra:terraform|\baws\b|azure|\bgcp\b|\bcloud\b|infrastructure-as-code|serverless|pulumi"
  "monitoring:monitoring|observability|logging|prometheus|grafana|tracing|metrics"
  "security:security|pentest|vulnerability|cryptography|\bctf\b|malware|reverse-engineering|encryption"
  "cli-tools:\bcli\b|terminal|command-line|\bshell\b|\btui\b"
  "dev-tools:developer-tools|vscode|vscode-extension|\beditor\b|linter|formatter|debugger|\bide\b"
  "ui-components:component-library|ui-kit|design-system|ui-components|\bicons\b"
  "design-resources:\bicons\b|\bfonts\b|\bcolors\b|animation|design-resources|\bfigma\b"
  "productivity:self-hosted|note-taking|productivity|\bpkm\b|obsidian|\btodo\b|task-management"
  "browser-extensions:chrome-extension|browser-extension|userscript"
  "awesome-lists:\bawesome\b|awesome-list|curated-list"
  "tutorials-courses:tutorial|\bcourse\b|learning-resources|roadmap|\bguide\b"
  "interview-prep:interview|leetcode|coding-interview|algorithm|data-structures"
  "books-notes:\bbook\b|ebook|\bnotes\b|cheatsheet"
  "templates-boilerplate:boilerplate|\btemplate\b|starter-kit|scaffold"
)

classify() {
  local haystack="$1"
  local rule cat pattern
  for rule in "${RULES[@]}"; do
    cat="${rule%%:*}"
    pattern="${rule#*:}"
    if grep -qiE "$pattern" <<<"$haystack"; then
      echo "$cat"
      return
    fi
  done
  echo "uncategorized"
}

# ---------------------------------------------------------------------------
# 拉取全部 star 仓库,统一落盘为 TSV: full_name / html_url / language / stars / topics / description
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

JQ_FILTER='.[] | [
    .full_name,
    .html_url,
    (.language // ""),
    (.stargazers_count | tostring),
    ((.topics // []) | join(",")),
    ((.description // "") | gsub("[\n\t]"; " "))
  ] | @tsv'

echo "开始拉取 star 仓库列表..."

if [[ "$USE_GH" -eq 1 ]]; then
  gh api --paginate \
    -H "Accept: application/vnd.github+json" \
    "/user/starred" \
    --jq "$JQ_FILTER" > "$TMPDIR/all.tsv"
else
  : > "$TMPDIR/all.tsv"
  page=1
  per_page=100
  while :; do
    http_code=$(curl -s -o "$TMPDIR/page.json" -w "%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${API_ROOT}/user/starred?per_page=${per_page}&page=${page}")

    if [[ "$http_code" == "401" ]]; then
      echo "认证失败:请检查 GITHUB_TOKEN 是否正确 / 是否已过期。" >&2
      exit 1
    fi
    if [[ "$http_code" == "403" ]] && grep -qi "rate limit" "$TMPDIR/page.json"; then
      echo "触发速率限制,等待 60 秒后重试..."
      sleep 60
      continue
    fi
    if [[ "$http_code" != "200" ]]; then
      echo "请求失败,HTTP $http_code:" >&2
      cat "$TMPDIR/page.json" >&2
      exit 1
    fi

    count=$(jq 'length' "$TMPDIR/page.json")
    if [[ "$count" -eq 0 ]]; then
      break
    fi

    jq -r "$JQ_FILTER" "$TMPDIR/page.json" >> "$TMPDIR/all.tsv"
    echo "已拉取第 ${page} 页"

    if [[ "$count" -lt "$per_page" ]]; then
      break
    fi
    page=$((page + 1))
  done
fi

total=$(wc -l < "$TMPDIR/all.tsv")
echo "共拉取到 ${total} 个仓库,开始分类..."

while IFS=$'\t' read -r full_name html_url language stars topics description; do
  haystack="${topics} ${language} ${full_name} ${description}"
  category=$(classify "$haystack")
  printf -- "- [%s](%s) ⭐%s — %s\n" "$full_name" "$html_url" "$stars" "$description" \
    >> "$TMPDIR/cat_${category}.md"
done < "$TMPDIR/all.tsv"

# ---------------------------------------------------------------------------
# 汇总生成 Markdown(按每类仓库数从多到少排序)
# ---------------------------------------------------------------------------
{
  echo "# GitHub Star 分类清单"
  echo
  echo "共 ${total} 个仓库。"
  echo
  echo "> 分类由关键词规则自动判断,不保证 100% 准确,请人工复核后再拖入对应的 GitHub List。"
  echo
} > "$OUT_FILE"

shopt -s nullglob
cat_files=("$TMPDIR"/cat_*.md)
if [[ ${#cat_files[@]} -gt 0 ]]; then
  while IFS= read -r line; do
    f=$(awk '{print $2}' <<<"$line")
    n=$(awk '{print $1}' <<<"$line")
    cat_name=$(basename "$f" .md)
    cat_name=${cat_name#cat_}
    {
      echo "## ${cat_name} (${n})"
      echo
      cat "$f"
      echo
    } >> "$OUT_FILE"
  done < <(wc -l "${cat_files[@]}" | grep -v total | sort -rn)
fi

echo "已生成 Markdown: $OUT_FILE"
echo
echo "分类结果统计:"
for f in "${cat_files[@]}"; do
  cat_name=$(basename "$f" .md)
  cat_name=${cat_name#cat_}
  n=$(wc -l < "$f")
  printf "  %-24s %s\n" "$cat_name" "$n"
done
