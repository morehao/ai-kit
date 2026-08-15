# tag 分支：基于分支打版本标签并推送

给选定分支的**远端最新提交**打注记 tag（annotated）并推送到远端。不切换分支、不修改工作区。仓库尚无 tag 时如实报告并走「首个版本」流程。

## 执行流程

1. **目标仓库**：同 pr-create/pr-merge，优先 `upstream`，回退 `origin`；`git remote get-url <目标仓库>` 确认存在可访问
2. **拉取最新**：`git fetch <目标仓库> --tags`（分支与 tag 都要最新）
3. **探测最新 tag 与来源分支**：
   - 最新 tag：`git tag --sort=-v:refname | head -1`（按版本号取最高）；tag 非版本号命名时退化为 `git tag --sort=-creatordate | head -1`（最近创建）
   - 来源分支：`git log -1 --format='%h %s' <tag>` 看 tag 指向的提交；`git branch -r --contains <tag>` 看哪些远端分支包含它，优先展示与 tag 提交同步（HEAD 指向同一提交）的分支，无则展示全部包含它的分支
   - **无 tag** → 如实报告「仓库尚无 tag」，按下方「无 tag」规则继续
4. **候选分支（让用户选）**：
   - 稳定分支优先：`main`/`master`，或**分支名含 `release` 关键字**（如 `release/2.0.0`、`release-2.0`、`v2.0-release`，命名不要求统一）
   - 其余：`<目标仓库>/<branch>` 中 `git log <latest-tag>..<目标仓库>/<branch>` 有提交的分支（比最新 tag 新、值得打 tag）；无 tag 时列出全部远端分支
   - 展示编号让用户选（1/2/3…），也允许用户直接输入分支名
5. **候选 tag（让用户选）**：
   - 有最新 tag 且为 semver（`v?X.Y.Z`）：按递增档提议 3 个候选 patch/minor/major（如 `v1.2.3` → `v1.2.4` / `v1.3.0` / `v2.0.0`），沿用现有 tag 的 `v` 前缀风格
   - **无 tag**：提议首个版本 `v0.1.0` 与 `v1.0.0`（默认 `v` 前缀）
   - 选择含 `release` 的分支且分支名带版本号时，候选 tag 优先从分支名推断（如 `release/2.0.0`、`release-v2.0` → `v2.0.0`），作为第 1 个候选
   - 用户可选候选或自定义（如 `v1.3.0-beta.1`）
   - **校验不冲突**：`git tag -l <tag>` 与 `git ls-remote --tags <目标仓库> <tag>` 均须无输出；冲突则提示换名，不覆盖已有 tag
6. **确认**：展示 `<tag>` @ `<branch>` @ `<sha> <subject>`（tag 指向的提交）让用户确认后再执行
7. **构建并推送**（同一 bash 链式，防半途）：
   `git fetch <目标仓库> --tags && git tag -a <tag> -m "release: <tag>" <目标仓库>/<branch> && git push <目标仓库> <tag> && echo "TAG_PUSH_OK"`
8. **验证**：输出出现 `TAG_PUSH_OK`，且 `git ls-remote --tags <目标仓库> <tag>` 与本地 `git tag -l <tag>` 均可见

## 注意事项

- 只打**注记 tag**（`-a` 带消息/作者/日期）；轻量 tag 无这些信息，不适合发版
- tag 指向 `<目标仓库>/<branch>` 的远端最新提交，不受本地分支状态影响
- 打 tag 不改任何文件/提交，**不切换当前分支**，无需工作区干净
- tag 已存在（本地或远端）→ 停并报告，`git tag` 默认拒绝覆盖、`git push` 也会被拒，不伪造成功

## 验收标准

- 本地与远端均可见新 tag，输出 `TAG_PUSH_OK`
- 未真正创建/推送（只列候选/只给文字）即失败，继续执行
- 任一步报错（网络/权限/tag 冲突/分支不存在）→ 停并完整报告原始报错，不伪造成功
- 当前分支与工作区保持不变（打 tag 不改文件）
