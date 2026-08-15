# commit-push 分支：分析变更并提交推送

先阅读 `references/commit-format.md` 获取格式/type 映射/scope/摘要规则，按以下流程执行。

## 执行流程（每步失败立即停并报告错误，不得跳过提交/推送）

1. **判断稳定分支**：`git branch --show-current` 确认当前分支；为稳定分支（`main`/`master`，或分支名含 `release` 关键字）时先**自动建分支**（见下方「稳定分支自动建分支」），切换后再继续
2. **暂存**：`git add -A`
3. **分析**：`git diff --staged` + `git status`，推断模块/scope，按主要意图归纳为单条 message
4. **生成**：按 `commit-format.md` 规则生成；scope 额外叠加：从变更文件路径提取模块名（如 `src/auth/` → `auth`），多模块取主要模块，无归属则不加
5. **提交推送**（同一 bash 调用链式）：`git commit -m "<生成的commit message>" && git push origin HEAD && echo "PUSH_OK"`
6. **验证**：输出出现 `PUSH_OK` 才算成功；否则视为失败，不得声称完成

## 稳定分支自动建分支（在稳定分支时执行）

稳定分支判定：分支名为 `main`/`master`，或分支名含 `release` 关键字（如 `release/2.0.0`、`release-2.0`、`v2.0-release`，命名不要求统一）。

稳定分支不允许直接提交，先基于代码变动自动创建分支再走后续流程，避免污染稳定分支：

1. **暂存**：`git add -A`（先把变动纳入到 diff 以便分析）
2. **确认有变动**：`git diff --staged` 或 `git status` 为空（无可提交内容）→ 如实报告「工作区无变更」，**不建分支、不提交**，直接停止
3. **推断 type**：从 `git diff --staged` 变更特征判断，映射同 `commit-format.md`（新增文件/新功能 → `feature`，修复 → `fix`，重构 → `refactor`，文档 → `docs` 等）；无明确时用 `feature`
4. **推断 scope**：从主要变更文件路径提取模块名（如 `src/auth/` → `auth`），无归属则省略
5. **生成分支名**：`<type>/<摘要>`（kebab-case 小写、≤50 字符）；有 scope 时摘要前加 `<scope>-`（如 `feature/user-auth`），无则省略；摘要用英文短词概括变更意图
6. **创建切换**（同一 bash 链式，从当前稳定分支的最新提交出发）：`git switch -c <branchname> && echo "BRANCH_OK"`
7. **验证**：出现 `BRANCH_OK` 且 `git branch --show-current` 为 `<branchname>`；分支已存在则加 `-2`/`-3` 后缀重试
8. 分支创建后，继续执行上方第 3 步起的提交推送流程（`git diff --staged` 保留、无需重新 add）

> 建分支名不引入用户中文描述时，基于 diff 归纳；用户已给中文描述则优先用其推断分支意图。

## 注意事项

- **稳定分支约束**：当前分支为稳定分支（`main`/`master` 或含 `release` 关键字）且**确有代码变动**时，才自动建分支后提交；其他分支直接提交。无论哪条，**无变动一律不建分支、不提交**（如实报告）
- message 内不要包含双引号 `"`，避免破坏 `git commit -m "..."` 的引号配对
- 若 `git commit` 报 `nothing to commit`（工作区无变更）或 `git add` 无内容，如实报告当前状态，不继续提交

## 验收标准

- 可见提交 `[hash] <message>` 与 `PUSH_OK`
- 未执行提交（只给文字）即失败，继续提交
- `git add/commit/push` 任一报错 → 停并完整报告，不伪造成功
- message 不含 `"`（防引号配对损坏）
- `nothing to commit` / `git add` 无内容 → 如实报告，不继续
