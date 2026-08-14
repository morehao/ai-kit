# pr 分支：创建/更新 PR 或 MR

对比当前与目标分支差异，自动识别 gh/glab，创建/更新 PR/MR。可选目标分支名 `$1`。

## 执行流程

1. **目标仓库**：优先 `upstream`，回退 `origin`；`git remote get-url <目标仓库>` 取 URL 并 `git config --get remote.<目标仓库>.url` 交叉确认；目标 ≠ `origin` 视为 fork
2. **工具**：解析 URL 主机名（https 取 path 中的 host，SSH 取 `git@host:` 中的 host）；主机 `github.com` → `gh`；其他（gitlab.com/自建 GitLab/Gitea 等）→ `glab`
3. **目标分支**：有 `$1` 直接用；否则探测默认分支（`git remote show <目标仓库>` 的 `HEAD branch`，或依次判 `main`、`master`）
4. **标题与描述**（跟随仓库语言）：
   - 差异：`git merge-base HEAD <目标仓库>/<目标分支>` 得基点、`git diff <基点>..HEAD`、`git log --oneline <基点>..HEAD`
   - 按仓库注释/README/commit message 语言决定中英文
   - 标题 Conventional-Commits 风格，如 `feat(scope): <摘要>`；描述概述意图、模块/文件、关键实现，换行分段
5. **查已有 PR/MR**：
   - gh：`gh pr list --repo <目标仓库> --head <当前分支> --base <目标分支> --json number,title --jq '.[0].number'`
   - glab：`glab mr list -R <目标仓库> --source-branch <当前分支>` 解析 IID
   - 有 → 更新；无 → 创建
6. **更新**（描述含换行/特殊字符时先写临时文件，gh 用 `--body-file`，glab 用 `--description "$(cat <临时文件>)"` 避免转义）：
   - gh：`gh pr edit <number> --repo <目标仓库> --title "<标题>" --body-file <临时文件>`
   - glab：`glab mr update <IID> -R <目标仓库> --title "<标题>" --description "$(cat <临时文件>)"`
7. **创建**：
   - gh fork（head 需带来源用户名前缀 `<你的用户名>:<当前分支>`）：`gh pr create --repo <目标仓库> --base <目标分支> --head <来源>:<当前分支> --title "<标题>" --body-file <临时文件>`
   - gh 非 fork：`gh pr create --repo <目标仓库> --base <目标分支> --head <当前分支> --title "<标题>" --body-file <临时文件>`
   - glab：`glab mr create -R <目标仓库> --source-branch <当前分支> --target-branch <目标分支> --title "<标题>" --description "$(cat <临时文件>)"`

## 前置检查

- 当前分支已推送（`git push -u origin HEAD` 未推先推），否则 gh/glab 定位不到 head
- `$1` 拼写错误会用错目标分支，此时报错停止
- 分支长时间未合并、差异较大（`git diff <基点>..HEAD --stat` 明显偏大）时，先提示用户是否在创建 PR 前 `git rebase <目标仓库>/<目标分支>` 同步最新主干以减小冲突

## 验收标准

- 见 `gh`/`glab` 返回的 PR/MR URL
- 更新场景：确认 URL 对应已有 PR/MR，而非新建
- 鉴权失败/命令报错 → 完整报告，不假装成功
- PR 仅覆盖单一功能/修复，不夹带无关改动（大而全 PR 属反模式，应拆小）
- 描述包含背景/动机（Why），而非只罗列改动
- PR 关联到对应 issue/任务（如仓库支持 `Closes #NN`）
