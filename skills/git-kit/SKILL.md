---
name: git-kit
description: Git 工作流辅助工具包。当用户要求生成 commit message、提交/推送代码变更、基于中文描述创建/切换分支、面向目标仓库创建/更新 PR/MR、或将当前 git 仓库瘦身为浅克隆时使用该 skill（含"写个commit信息""提交一下""开个分支做XX""提个PR""把仓库瘦身"等模糊表述）。
---

# Git Kit

Git 常见操作的统一入口。先按「意图路由」理解用户要做什么，落到一个分支执行，再按该分支的验收标准收尾。

## 意图路由（决策树）

从用户消息解析意图，落入唯一分支。**不得跳过路由直接执行**。

| 分支 key | 命中信号（用户消息中出现） | 对应目的 |
|---------|--------------------------|---------|
| `commit-push` | 提交/推送当前变更（"提交""push""commit""推送"） | 分析 diff → 生成 message → 真实提交并推送到远端 |
| `commit-message` | 只要 commit message 文案（"写个commit消息""生成commit信息"，或用户明确说"不用提交、只要文案"） | 仅返回 commit message 文字 |
| `branch` | 分支 + 中文描述（"建个分支…""切到新分支…""开个分支做XX"） | 生成候选分支名，选择后从基准创建并切换 |
| `pr` | PR/MR/合并请求（"提PR""创建合并请求""更新MR"） | 识别 gh/glab，向目标仓库创建/更新 PR/MR |
| `slim` | 仓库瘦身/浅克隆/减小体积（"瘦身""清理git历史""shallow clone"） | 浅克隆瘦身，保留最近 N 天历史与本地改动 |

**模糊请求直接按意图覆盖交叉处理：**
- 既说"提交"又说"推送" → `commit-push`（含生成 message）；只说"信息/文案"或明确"不提交" → `commit-message`。
- 未命中任何信号 → 停止并询问用户具体要做的 Git 操作，不擅自动手。

**参数约定**（从用户消息提取，优先于任何上下文）：
- `branch`：提取中文描述（候选分支名唯一依据）。
- `pr`：可选目标分支名；没有则探测目标仓库默认分支。
- `slim`：可选保留天数 `N`；没有则默认 `30 days ago`。

**两类消息的上下文约束：**
- 命中 `commit-message` 或 `branch` 分支时，只处理用户提供的话术/描述，**忽略任何代码、文件、git diff、git status 等上下文**。
- 命中 `commit-push`、`pr`、`slim` 分支时，主动读取 git 状态是必要的（diff/remote/历史）。

---

## 分支：commit-push

分析当前待提交变更，生成 Conventional Commits message 并提交推送。

### 执行流程（每步失败立即停并报告错误，不得跳过提交/推送）

1. **暂存**：`git add -A`
2. **分析**：`git diff --staged` + `git status`，推断模块/scope，按主要意图归纳为单条 message
3. **生成**：沿用下方「commit 格式」规则；scope 额外叠加：从变更文件路径提取模块名（如 `src/auth/` → `auth`），多模块取主要模块，无归属则不加
4. **提交推送**（同一 bash 调用链式）：
   ```
   git commit -m "<生成的commit message>" && git push origin HEAD && echo "PUSH_OK"
   ```
5. **验证**：输出出现 `PUSH_OK` 才算成功；否则视为失败，不得声称完成

### commit 格式（commit-push 与 commit-message 共用）
`<type>(可选scope): <摘要>`

**type 映射**：
| 中文语义 | type |
|---------|------|
| 新增、添加、实现 | feat |
| 修复、解决 | fix |
| 重构、调整结构 | refactor |
| 文档 | docs |
| 格式、空格、缩进 | style |
| 测试 | test |
| 构建、依赖、脚本 | chore |
| 性能、优化 | perf |

**scope 推断**：从描述抽象功能模块（如"登录页密码验证" → `auth`），不明确则省略，多模块取主模块。

**摘要规则**：祈使句动词原形开头；无句号；≤72 字符；首字母小写（专有名词除外）；简洁概括意图；不含双引号 `"`。

**示例**：
- 修复登录页密码验证失败 → `fix(auth): fix password validation on login page`
- 新增用户导出数据功能 → `feat(user): add data export feature`

### 验收标准
- 可见提交 `[hash] <message>` 与 `PUSH_OK`
- 未执行提交（只给文字）即失败，继续提交
- `git add/commit/push` 任一报错 → 停并完整报告，不伪造成功
- message 不含 `"`（防引号配对损坏）
- `nothing to commit` / `git add` 无内容 → 如实报告，不继续

---

## 分支：commit-message

仅将用户中文描述转为 commit message。**不执行任何 git 操作。**

- 严格遵守「commit 格式」「type 映射」「scope 推断」「摘要规则」
- 若用户已给出具体描述则直接用；若空，基于消息上下文推理
- 默认只返回文字；如需提交可向用户说明
- **输出**：只输出一行 commit message，无解释、无额外说明

---

## 分支：branch

基于中文描述生成 3 个候选分支名，用户选一后从基准分支创建并切换。只处理用户文本，忽略代码/文件/diff。

### 执行流程

1. **确定基准**：让用户选 A（远端最新 main/master，探测 `origin/main` 与 `origin/master` 取存在者作基准引用 `origin/<base>`，不拉取本地分支）或 B（当前分支）
2. **生成候选 3 个**：`<type>/<简短英文描述>`，风格/粒度各异（如 `feature/user-auth`、`feature/add-user-authentication`、`feature/login-secure-access`）；type 用下方「分支 type 映射」
3. **用户选**：请用户输 1/2/3
4. **创建切换**（同一 bash 链式）：
   - 基准 A：`git fetch origin && git switch -c <branchname> origin/<base> && echo "SWITCH_OK"`
   - 基准 B：`git switch -c <branchname> && echo "SWITCH_OK"`
5. **验证**：出现 `SWITCH_OK` 且 `git branch --show-current` 为 `<branchname>`

### 分支 type 映射（与 commit 不同，前缀用功能词）
| 中文语义 | 前缀 |
|---------|------|
| 新增、添加、实现 | feature |
| 修复、解决 | fix |
| 重构 | refactor |
| 文档 | docs |
| 格式/空格 | style |
| 测试 | test |
| 构建/依赖/脚本 | chore |
| 性能/优化 | perf |

**候选规则**：三个风格/粒度不同；均 kebab-case 小写、≤50 字符、简洁、概括意图；不与已有分支冲突（可先 `git branch --list`/`git branch -r` 核对，冲突换名）。

### 验收标准
- 出现 `SWITCH_OK` 且 `git branch --show-current` 为新分支
- 未真正创建切换（仅列候选名）即失败，继续
- 分支已存在/`git switch` 报错等 → 停并完整报告，不伪造成功

---

## 分支：pr

对比当前与目标分支差异，自动识别 gh/glab，创建/更新 PR/MR。可选目标分支名从消息提取。

### 执行流程

1. **目标仓库**：优先 `upstream`，回退 `origin`；`git remote get-url` 取 URL 并 `git config` 交叉确认；目标 ≠ `origin` 视为 fork
2. **工具**：URL 主机为 `github.com` → `gh`；其他（gitlab.com/自建 GitLab/Gitea 等）→ `glab`
3. **目标分支**：有消息提取的目标分支直接用；否则探测默认分支（`remote show` 的 `HEAD branch`，或依次判 `main`、`master`）
4. **标题与描述**（跟随仓库语言）：
   - 差异：`git merge-base HEAD <仓库>/<目标分支>`、`git diff <基点>..HEAD`、`git log --oneline <基点>..HEAD`
   - 按仓库注释/README/commit 语言决定中英文
   - 标题 Conventional-Commits 风格；描述概述意图、模块/文件、关键实现，换行分段
5. **查已有 PR/MR**：
   - gh：`gh pr list --repo <目标仓库> --head <当前分支> --base <目标分支> --json number,title --jq '.[0].number'`
   - glab：`glab mr list -R <目标仓库> --source-branch <当前分支>` 解析 IID
   - 有 → 更新；无 → 创建
6. **更新**（描述含换行时写临时文件，gh 用 `--body-file`，glab 用 `--description "$(cat <临时文件>)"`）：
   - gh：`gh pr edit <number> --repo <目标仓库> --title "<标题>" --body-file <临时文件>`
   - glab：`glab mr update <IID> -R <目标仓库> --title "<标题>" --description "$(cat <临时文件>)"`
7. **创建**：
   - gh fork：`gh pr create --repo <目标仓库> --base <目标分支> --head <来源>:<当前分支> --title "<标题>" --body-file <临时文件>`
   - gh 非 fork：`gh pr create --repo <目标仓库> --base <目标分支> --head <当前分支> --title "<标题>" --body-file <临时文件>`
   - glab：`glab mr create -R <目标仓库> --source-branch <当前分支> --target-branch <目标分支> --title "<标题>" --description "$(cat <临时文件>)"`

**前置**：当前分支已推送（`git push -u origin HEAD` 未推先推），否则 gh/glab 定位不到 head。

### 验收标准
- 见 `gh`/`glab` 返回的 PR/MR URL
- 更新场景：确认 URL 对应已有 PR/MR，而非新建
- 鉴权失败/命令报错 → 完整报告，不假装成功

---

## 分支：slim

把当前 git 仓库瘦身成浅克隆，默认保留 30 天历史；天数参数从消息提取。**最高优先级：绝不丢失本地未提交改动。**

### 执行流程（每步失败立即停并报错）

1. **自提交安全校验**：存在作者/提交者为当前 git 用户本人的提交即中止，不动手：
   ```sh
   name="$(git config user.name)"; email="$(git config user.email)"
   if [ -n "$name" ] && git log --all --author="$name" --format='%H' | grep -q .; then
     echo "检测到本人提交（作者=$name），禁止执行本命令" >&2; exit 1
   fi
   if [ -n "$email" ] && git log --all --committer="$email" --format='%H' | grep -q .; then
     echo "检测到本人提交（提交者=$email），禁止执行本命令" >&2; exit 1
   fi
   ```
2. 记录瘦身前体积：`du -sh .git`
3. 安全检查：`git status --porcelain`；有改动（M/A/D/??）则缓存 `git stash push -u -m "slim-backup-$(date +%s)"`
4. 深度：消息提取 `N` → `N days ago`；默认 `30 days ago`
5. 浅拉取：`git fetch --shallow-since="<深度>" --prune origin "$(git branch --show-current)"`
6. 本地对齐远端：优先 `git merge --ff-only origin/<当前分支>`；ff 失败改 `git reset --soft origin/<当前分支>`
7. 收缩：`git reflog expire --expire=now --all && git gc --prune=now`
8. 恢复：`git stash pop`（若有）
9. 核对：`git status --porcelain` 与步骤 3 一致；输出体积对比

### 验收标准
- `.git` 体积明显缩小
- `git pull` 可正常执行
- 本地改动完整保留

### 警示（可向用户提示）
- N 天前的提交将不可见；需要时可 `git fetch --unshallow` 恢复完整历史
- 执行前确认当前分支即所要对齐的目标分支
