# pr-merge 分支：合并 PR/MR

合并后**删除原分支**，切回主干并拉取最新代码。自动识别 gh/glab。默认 squash 合并（用户可覆盖）。

## 确定编号（按优先级）

1. **用户显式提供**：`$1`（斜杠命令第一参数）或消息中的编号/URL（`#123`、`github.com/.../pull/123`、`gitlab.com/.../-/merge_requests/123`）→ 直接提取编号
2. **上下文探测**：无显式编号时，若当前分支非主干（main/master），探测当前分支关联的开放 PR/MR：
   - gh：`gh pr view --json number,state,baseRefName --jq '{number,state,base:.baseRefName}'`（无参数即取当前分支 PR）；报错或 `state` 非 `OPEN` → 视为探测不到
   - glab：`glab mr view <当前分支> --output json | jq '{iid, state, target_branch}'` 或 `glab mr list --source-branch <当前分支>` 解析 IID；`state` 非 `opened` → 视为探测不到
3. **确认**：无论来源，合并前把「编号 + 标题 + 目标分支 + 将删除的 head 分支」展示给用户确认；有歧义（探测到多个）时让用户选
4. **探测不到 → 必须向用户索要编号**，不猜测、不默认用 1 或当前分支猜

## 前置检查

1. **工作区干净**：`git status --porcelain` 须为空；有未提交改动 → 提示先提交/stash，不强行合并
2. **目标仓库与工具**（同 pr-create）：目标仓库优先 `upstream`，回退 `origin`；`git remote get-url <目标仓库>` 解析主机，`github.com` → `gh`，其他（gitlab.com/自建 GitLab/Gitea 等）→ `glab`
3. **校验 PR/MR 存在且未合并**：
   - gh：`gh pr view <id> --json state,baseRefName,headRefName --jq '{state,base:.baseRefName,head:.headRefName}'`，`state` 须为 `OPEN`
   - glab：`glab mr view <id> --output json | jq '{state, base:.target_branch, head:.source_branch}'`，`state` 须为 `opened`
   - 已 `MERGED`/`merged` 或 `CLOSED`/`closed`、查不到 → 停止并完整报告
4. 记录 base/head 分支名；**若当前分支 == head**，先 `git switch <base>` 再合并（避免删除当前所在分支失败）

## 执行流程

1. **合并（删除原分支）**：
   - gh：`gh pr merge <id> --squash --delete-branch`（`--delete-branch` 同时删本地+远端分支；用户要求 merge/rebase 时换 `--merge`/`--rebase`）
   - glab：`glab mr merge <id> --squash --remove-source-branch --yes`（`--remove-source-branch` 删远端源分支，`--yes` 跳过确认；用户要求 rebase 时换 `--rebase`）
2. **切回主干**：`git switch <base>`；本地无该分支则 `git switch -c <base> --track origin/<base>`
3. **更新代码**：`git pull --ff-only origin <base>`（仓库习惯非 ff 时用 `git pull origin <base>`）
4. **清理本地残留分支**：本地仍存在 `<head>` 分支则 `git branch -D <head>`（gh 已删本地；glab 只删远端，本地残留需手动清理）

## 验收标准

- 复核状态：gh `gh pr view <id> --json state --jq .state` 为 `MERGED`；glab `glab mr view <id> --output json | jq -r .state` 为 `merged`
- 原分支已删：`git ls-remote --heads origin <head>` 无输出；head 为默认分支/受保护分支等删除失败场景 → 如实报告未删除，不假装成功
- 当前分支为 `<base>`，`git status --porcelain` 为空，`git log --oneline -3` 已含合并后的最新提交
- 任一步失败（冲突未解决、CI/检查未过、权限不足等）→ 停在当前状态完整报告 gh/glab 原始报错，不伪造成功
