---
description: 基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab）
---

# 任务
对比当前分支与目标分支的代码差异，自动判断工具（`gh` 或 `glab`），向目标仓库发起 Pull Request 或 Merge Request；若已存在则更新其标题与描述。可选传参 `$1` 指定目标分支名。

# 执行流程（每步失败立即停止并报告错误，不得跳过）

## 1. 确定目标仓库
- 优先使用 `upstream` remote（fork 场景）；若不存在，回退到 `origin`
- 用 `git remote get-url <目标仓库>` 获取 URL；用 `git config --get remote.<目标仓库>.url` 交叉确认
- 判断 fork 场景：目标仓库 ≠ 当前 `origin` 时视为 fork，创建时需要指定来源用户名

## 2. 选择工具（gh / glab）
- 解析目标仓库 URL 的主机名（https 取 path 中的 host，SSH 取 `git@host:` 中的 host）
- 主机是 `github.com` → 使用 `gh`
- 主机是**任何其他**（gitlab.com、自建 GitLab、Gitea 等）→ 一律使用 `glab`

## 3. 确定目标分支
- 若用户传入 `$1` 分支名 → 直接使用，作为目标分支
- 否则探测目标仓库默认分支，优先级：
  1. `git remote show <目标仓库>` 输出的 `HEAD branch: XXX`
  2. 依次判断 `main`、`master` 是否存在（`git ls-remote --heads <目标仓库> <分支>` 非空即存在）

## 4. 生成标题与描述（跟随仓库语言）
- 获取差异：
  - `git merge-base HEAD <目标仓库>/<目标分支>` 得基点
  - `git diff <基点>..HEAD` 查看完整差异
  - `git log --oneline <基点>..HEAD` 查看提交历史
- **语言跟随**：根据现有代码注释、README、commit message 语言推断（中文仓库用中文，英文仓库用英文）
- 标题：Conventional-Commits 风格摘要，如 `feat(scope): <摘要>`
- 描述（body/description）：概述改动意图、涉及的主要模块/文件、关键实现点，可含验证方式；用换行分段

## 5. 查询已有 PR/MR（避免重复创建）
- gh：`gh pr list --repo <目标仓库> --head <当前分支> --base <目标分支> --json number,title --jq '.[0].number'`
- glab：`glab mr list -R <目标仓库> --source-branch <当前分支>` 解析 IID
- 若有结果 → 进入「更新」；无 → 进入「创建」

## 6. 更新已有 PR/MR
- gh：`gh pr edit <number> --repo <目标仓库> --title "<标题>" --body-file <临时文件>`
- glab：`glab mr update <IID> -R <目标仓库> --title "<标题>" --description "$(cat <临时文件>)"`
- 描述含换行/特殊字符时，先写入临时文件，gh 用 `--body-file`，glab 用 `--description "$(cat <临时文件>)"` 方式读取，避免 shell 转义问题

## 7. 创建新 PR/MR
- gh（fork 场景，head 需带来源用户名前缀 `<你的用户名>:<当前分支>`）：`gh pr create --repo <目标仓库> --base <目标分支> --head <来源>:<当前分支> --title "<标题>" --body-file <临时文件>`
- gh（非 fork）：`gh pr create --repo <目标仓库> --base <目标分支> --head <当前分支> --title "<标题>" --body-file <临时文件>`
- glab：`glab mr create -R <目标仓库> --source-branch <当前分支> --target-branch <目标分支> --title "<标题>" --description "$(cat <临时文件>)"`

# 前置检查
- 当前分支已推送（`git push -u origin HEAD` 若未推送则先推送），否则 gh/glab 无法定位 head 分支
- `$1` 若提供且拼写错误，会用到不存在的目标分支，此时报错停止

# 验收标准
- 必须看到 `gh` / `glab` 返回的 PR/MR URL 才算成功
- 更新场景：确认返回的是对应已有 PR/MR 的 URL，而非新建
- 若鉴权失败或命令报错，完整报告错误输出，不得假装成功
