---
name: git-kit
description: Git 工作流辅助工具包。当用户要求生成 commit message、提交/推送代码变更、基于中文描述创建/切换分支、面向目标仓库创建/更新 PR/MR、按编号合并 PR/MR 并回主干更新、给分支打版本标签并推送、端到端发版（升版本+提交+打 tag+推送+验证发布）、将当前 git 仓库瘦身为浅克隆、或拉取并分类 GitHub star 仓库时使用该 skill（含"写个commit信息""提交一下""开个分支做XX""提个PR""把PR合并掉""打个tag""发版""发布新版本""把仓库瘦身""分类我的star"等模糊表述）。
---

# Git Kit

Git 常见操作的统一入口。先按「意图路由」理解用户要做什么，落到一个分支执行，再按该分支的验收标准收尾。

本 skill 采用多文件结构。**主文件只含意图路由。** 命中某个分支后，按「按需加载」指引读取对应子文件执行其完整流程，避免一次性加载全部内容。

## 意图路由（决策树）

从用户消息解析意图，落入唯一分支。**不得跳过路由直接执行。**

| 分支 key | 命中信号（用户消息中出现） | 对应子文件 |
|---------|--------------------------|-----------|
| `commit-push` | 提交/推送当前变更（"提交""push""commit""推送"） | `references/commit-push.md`（含 `commit-format.md`） |
| `commit-message` | 只要 commit message 文案（"写个commit消息""生成commit信息"，或用户明确说"不用提交、只要文案"） | `references/commit-message.md`（含 `commit-format.md`） |
| `branch` | 分支 + 中文描述（"建个分支…""切到新分支…""开个分支做XX"） | `references/branch.md` |
| `pr-create` | 创建/更新 PR/MR（"提PR""创建合并请求""更新MR"） | `references/pr-create.md` |
| `pr-merge` | 合并 PR/MR 并回主干更新（"合并PR""合并MR""merge PR""把PR合掉""合入主干"） | `references/pr-merge.md` |
| `release` | 端到端发版：升版本 → 提交 → 打 tag → 推送 → 验证发布（"发版""发布新版本""发个版本""release 流程""升版本发版""出个 release"） | `references/release.md` |
| `tag` | 只给分支打版本标签并推送、不改仓库文件（"打tag""打个tag""打标签""只打个标签""release tag"） | `references/tag.md` |
| `slim` | 仓库瘦身/浅克隆/减小体积（"瘦身""清理git历史""shallow clone"） | `references/slim.md` |
| `star-classify` | 拉取并分类自己 star 的 GitHub 仓库（"分类我的star""把我star的仓库整理成清单"） | `references/star-classify.md` |

**模糊请求直接按意图覆盖交叉处理：**
- 既说"提交"又说"推送" → `commit-push`（含生成 message）；只说"信息/文案"或明确"不提交" → `commit-message`。
- PR/MR 相关：**"合并请求"作 GitLab 术语（名词）** → `pr-create`；**"合并"作动词**（合并XX/合入XX/merge）→ `pr-merge`。
- 发版相关：说"发版/发布新版本/发个版本/release"且**未限定只打 tag** → `release`（端到端，会改版本文件）；明确"只打 tag/打标签/不动代码/不升版本" → `tag`。
- 未命中任何信号 → 停止并询问用户具体要做的 Git 操作，不擅自动手。

**参数约定**（从用户消息提取，优先于任何上下文）：
- `branch`：提取中文描述（候选分支名唯一依据）。
- `pr-create`：可选目标分支名；没有则探测目标仓库默认分支。
- `pr-merge`：优先取用户显式提供的编号/URL；没有则探测当前分支关联的开放 PR/MR；无论来源，合并前都展示「编号 + 标题 + 目标分支 + head 分支处理方式（删除 / 保留）」并给用户**三选项（是 / 否 / 自定义 id）**确认（**release 等发布分支一律保留不删**，判定在合并前完成）；探测不到则要求用户提供编号，不猜测。
- `release`：可选版本号或档位（`$1`，如 `v1.2.0` / `1.2.0` / `--patch` / `--minor` / `--major`）；没有则用 `scripts/git-release-probe.sh` 探测版本文件、最新 tag 与下一版本候选，**先展示给用户确认**（版本号、目标分支、tag 三件套）再动手。
- `tag`：可选分支名或 tag 名（`$1`）；没有则探测最新 tag 与来源分支、候选分支、候选版本号并**先展示给用户选择确认**，不擅自决定打哪个分支/版本。
- `slim`：可选保留天数 `N`；没有则默认 `30 days ago`。

**两类消息的上下文约束：**
- 命中 `commit-message` 或 `branch` 分支时，只处理用户提供的话术/描述，**忽略任何代码、文件、git diff、git status 等上下文**。
- 命中 `commit-push`、`pr-create`、`pr-merge`、`release`、`tag`、`slim` 分支时，主动读取 git 状态是必要的（diff/remote/历史）。

## 按需加载

确认分支后，执行以下子文件的完整流程：

- `commit-push` 或 `commit-message`：先 `read references/commit-format.md`，再 `read references/<对应分支>.md`，最后按该文件执行。
- `branch`：`read references/branch.md`。
- `pr-create`：`read references/pr-create.md`。
- `pr-merge`：`read references/pr-merge.md`。
- `release`：`read references/release.md`，按其中指引运行 `<skill 基目录>/scripts/git-release-probe.sh`（只读探测，可在任意目录运行、脚本自行定位仓库根；单一真源，打 tag 步骤复用 `references/tag.md` 规则）。
- `tag`：`read references/tag.md`。
- `slim`：`read references/slim.md`，按其中指引运行 `scripts/git-slim.sh`（脚本为单一真源，与 `/git/slim` 命令共用）。
- `star-classify`：`read references/star-classify.md`，按其中指引运行 `scripts/git-star.sh`。
