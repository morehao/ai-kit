# pr-merge 分支：合并 PR/MR

合并后**删除原分支**（源分支为 release 分支时**保留不删**），切回主干并拉取最新代码。自动识别 gh/glab。默认 squash 合并（用户可覆盖）。

## 确定编号（按优先级）

1. **用户显式提供**：`$1`（斜杠命令第一参数）或消息中的编号/URL（`#123`、`github.com/.../pull/123`、`gitlab.com/.../-/merge_requests/123`）→ 直接提取编号
2. **上下文探测**：无显式编号时，若当前分支非主干（main/master），探测当前分支关联的开放 PR/MR：
   - gh：`gh pr view --json number,state,baseRefName --jq '{number,state,base:.baseRefName}'`（无参数即取当前分支 PR）；报错或 `state` 非 `OPEN` → 视为探测不到
   - glab：`glab mr view <当前分支> --output json | jq '{iid, state, target_branch}'` 或 `glab mr list --source-branch <当前分支>` 解析 IID；`state` 非 `opened` → 视为探测不到
3. **三选项确认**：无论编号来自显式提供还是上下文探测，合并前都把「编号 + 标题 + 目标分支 + head 分支处理方式（删除 / 保留，含保留原因）」展示给用户，并提供三个选项（其中 head 与处理方式先按「前置检查」取到，再按「源分支保护」判定后填入；确认时就要定下来，因为删除参数随合并一次性发出）：
   - **是**：确认按当前编号合并，继续执行
   - **否**：取消本次合并，停在当前状态
   - **自定义 id**：用户另给一个编号/URL，替换当前编号 → 回到「前置检查」重新校验该 PR/MR，校验不过按失败处理
   - 探测到多个候选（有歧义）时，先让用户选定一个编号，再做上述三选项确认
4. **探测不到 → 必须向用户索要编号**，不猜测、不默认用 1 或当前分支猜

## 前置检查

1. **工作区干净**：`git status --porcelain` 须为空；有未提交改动 → 提示先提交/stash，不强行合并
2. **目标仓库与工具**（同 pr-create）：目标仓库优先 `upstream`，回退 `origin`；`git remote get-url <目标仓库>` 解析主机，`github.com` → `gh`，其他（gitlab.com/自建 GitLab/Gitea 等）→ `glab`
3. **校验 PR/MR 存在且未合并**：
   - gh：`gh pr view <id> --json state,baseRefName,headRefName --jq '{state,base:.baseRefName,head:.headRefName}'`，`state` 须为 `OPEN`
   - glab：`glab mr view <id> --output json | jq '{state, base:.target_branch, head:.source_branch}'`，`state` 须为 `opened`
   - 已 `MERGED`/`merged` 或 `CLOSED`/`closed`、查不到 → 停止并完整报告
4. 记录 base/head 分支名；**若当前分支 == head**，先 `git switch <base>` 再合并（避免删除当前所在分支失败）

## 源分支保护（是否需要删除 head 分支）

合并参数里的删除动作一经发出就**不可撤销**，故必须在合并**之前**判定 `<head>` 能否删除。判定结果 `DELETE` / `KEEP` 直接决定后面的合并命令形态。

1. **release 分支一律不删**：`<head>` 命中以下任一形态 → 标记 **`KEEP`**（大小写不敏感）
   - 精确等于 `release` / `releases`
   - `release/`、`releases/`、`release-`、`releases-` 前缀，如 `release/1.2.0`、`release-v2`、`release-2025.09`
   - 其他命名习惯的发布/维护分支（如 `stable/*`、`hotfix/release-*` 等语义等同 release 的长期分支）同样按 `KEEP` 处理
2. **兜底**：head 为默认/受保护/长期分支（`main`、`master`、`develop` 等），或**无法确定 head 归属**时，一律按 `KEEP` 处理（宁可不删，也不误删）
3. **用户显式指令优先**：用户明确说「保留分支 / 不要删」「这个也删掉」时，按用户要求执行（但 release 分支被要求删除时，先复述风险让用户二次确认）
4. **其余情况标记 `DELETE`**：feature / fix / hotfix / refactor / docs / test / chore / perf / experiment / poc 等常规开发分支
5. `KEEP` 时：**不向 gh/glab 传任何删除参数**，并跳过「清理本地残留分支」；本地 `<head>` 分支一并保留（远端保留而本地删除会造成状态不一致）

## 执行流程

1. **合并**（按保护的判定结果选命令；用户要求 merge/rebase 时把 `--squash` 换 `--merge`/`--rebase`）：
   - `DELETE`（常规分支）：
     - gh：`gh pr merge <id> --squash --delete-branch`（`--delete-branch` 同时删本地+远端分支）
     - glab：`glab mr merge <id> --squash --remove-source-branch --yes`（`--remove-source-branch` 删远端源分支，`--yes` 跳过确认）
   - `KEEP`（release 分支等）：删掉删除参数，其余不变
     - gh：`gh pr merge <id> --squash`
     - glab：`glab mr merge <id> --squash --yes`
2. **切回主干**：`git switch <base>`；本地无该分支则 `git switch -c <base> --track origin/<base>`
3. **更新代码**：`git pull --ff-only origin <base>`（仓库习惯非 ff 时用 `git pull origin <base>`）
4. **清理本地残留分支**（仅 `DELETE`）：本地仍存在 `<head>` 分支则 `git branch -D <head>`（gh 已删本地；glab 只删远端，本地残留需手动清理）

## 验收标准

- 复核状态：gh `gh pr view <id> --json state --jq .state` 为 `MERGED`；glab `glab mr view <id> --output json | jq -r .state` 为 `merged`
- 原分支按判定结果处理，两条都要核对：
  - `DELETE`：`git ls-remote --heads origin <head>` 无输出，且本地 `git branch --list <head>` 无输出
  - `KEEP`：`git ls-remote --heads origin <head>` 与本地 `git branch --list <head>` **均仍有输出**（保留是预期结果，不得当失败；也不得"顺手"删掉）
- 当前分支为 `<base>`，`git status --porcelain` 为空，`git log --oneline -3` 已含合并后的最新提交
- 任一步失败（冲突未解决、CI/检查未过、权限不足等）→ 停在当前状态完整报告 gh/glab 原始报错，不伪造成功；head 为受保护分支导致删除失败（本应 `KEEP` 却发起了删除）→ 如实报告未删除

