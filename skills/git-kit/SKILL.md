---
name: git-kit
description: Git 工作流辅助工具包。当用户要求生成 commit message、提交/推送代码变更、基于中文描述创建/切换分支、面向目标仓库创建/更新 PR/MR、或将当前 git 仓库瘦身为浅克隆时使用该 skill（含"写个commit信息""提交一下""开个分支做XX""提个PR""把仓库瘦身"等模糊表述）。
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
| `pr` | PR/MR/合并请求（"提PR""创建合并请求""更新MR"） | `references/pr.md` |
| `slim` | 仓库瘦身/浅克隆/减小体积（"瘦身""清理git历史""shallow clone"） | `references/slim.md` |

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

## 按需加载

确认分支后，执行以下子文件的完整流程：

- `commit-push` 或 `commit-message`：先 `read references/commit-format.md`，再 `read references/<对应分支>.md`，最后按该文件执行。
- `branch`：`read references/branch.md`。
- `pr`：`read references/pr.md`。
- `slim`：`read references/slim.md`，按其中指引运行 `scripts/git-slim.sh`（脚本为单一真源，与 `/git/slim` 命令共用）。
