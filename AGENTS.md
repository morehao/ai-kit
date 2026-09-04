# AGENTS.md

本仓库集中管理个人 opencode 自定义扩展：`commands-opencode/`（斜杠指令）+ `skills/`（技能）。所有说明用**简体中文**。

## 部署方式（任何修改前必读）

这些扩展通过**软链接**注册到 `~/.config/opencode/`，本仓是唯一真源：
- `ln -sfn <ai-kit>/skills/* ~/.config/opencode/skills/`
- `ln -sfn <ai-kit>/commands-opencode/git ~/.config/opencode/command/git`

**`skills/` 下只允许放技能的目录**（如 `git-kit/`），禁止放置任何松散说明文件。因为 `ln -sfn skills/*` 会展开全部条目，新增的非目录文件会被一并软链过去。根 `README.md` 即安装说明。

`.gitignore` 忽略了 `.opencode/`、`.superpowers/`、`docs/superpowers/`（本地草稿，不入库）。

## 目录结构速览

- `commands-opencode/git/*.md` — 斜杠指令。是**委托壳**，只加载 `git-kit` skill 并按某种意图执行，不含逻辑。
- `skills/git-kit/` — Git 工作流（message/commit-push/branch/pr-create/pr-merge/slim/star）。**请求分叉点：多文件结构**。`SKILL.md` 只做「意图路由」+「按需加载」指引；真实逻辑在 `references/`（各分支 .md）与 `scripts/`（.sh 脚本）。
  - `commands-opencode/git/*` 与 `skills/git-kit` **共享同一实现**，互为两条入口（斜杠 / 自然语言）。改命令类的需求应落到 skill 分支，命令只保留委托壳。
- `skills/project-insight/` — 开源项目深度解读。`SKILL.md` 较大（约 50KB），含铁律：真源引用 `文件:行号` 必须经 `scripts/verify-references.mjs` 程序化重定位验证（指纹用**首末行双锚点**，不整段贴码；旧 snippet 格式仅存量兼容），Mermaid 图必须经 `scripts/check-mermaid.mjs` 校验全 `OK`。`[UNVERIFIED]`/`[MERMAID-ERROR]` 一律保留不静默放过。参考性内容按需加载在 `references/`（`data-model-guide.md` 五要素成文细则、`errors-and-fixes.md` 查错表、`analysis-guide.md` 深度方法论、`large-repo-workflow.md` 并行流程、`project-types/` 类型规格）。落盘后**不做 git add/commit**。
- `skills/svg-maker/`、`skills/tech-design-proposal/` — 单文件 skill。

## 运行脚本（project-insight 的 node_modules 不入库）

`skills/project-insight/scripts/` 依赖 `mermaid`、`jsdom`。`node_modules` 被 gitignore，**首次需在其中 `npm install`**；若本机用 `cp -r` 复制注册而非软链，复制后要在副本的 `scripts/` 重装。校验用 node 直跑（不是打包器）：
- `node scripts/verify-references.mjs <kb_repo> <解读.md>...`
- `node scripts/check-mermaid.mjs <解读.md>...`（在 `scripts/` 下）

## 写作约定

- 中文为主，代码/术语保留英文。
- 子文档**主题语义命名**（`architecture.md`、`data-model.md`），**不用数字序号前缀**。
- 标题用 Markdown 天然层级语义式命名，不加 `## 1. X` 这类数字前缀。
- git-kit 用 Conventional Commits；分支前缀映射见 `skills/git-kit/references/branch.md`（feature/fix/hotfix/refactor/release/experiment/poc 等）。
