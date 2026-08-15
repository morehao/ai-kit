# opencode 扩展工具集 (ai-kit)

本项目集中管理我要用的 opencode 自定义扩展：一部分是 `commands/`（斜杠指令），一部分是 `skills/`（技能）。

## 目录结构

```
ai-kit/
├── README.md                  # 本说明
├── LICENSE
├── commands/                  # opencode 斜杠指令
│   ├── README.md              # 指令功能与用法说明
│   └── git/                   # Git 相关指令
│       ├── branch.md
│       ├── message.md
│       ├── pr-create.md
│       ├── pr-merge.md
│       ├── tag.md
│       ├── commit-push.md
│       ├── slim.md
│       └── star-classify.md
└── skills/                    # opencode 技能
    ├── git-kit/               # Git 工作流辅助（message/commit-push/branch/pr-create/pr-merge/tag/slim/star）
    │   ├── references/        # 拆分的辅助逻辑
    │   └── scripts/           # 附带脚本
    ├── project-insight/       # 开源项目深度解读
    │   ├── references/        # 拆分的辅助逻辑
    │   └── scripts/           # 附带脚本
    ├── tech-design-proposal/  # 技术方案/架构设计文档生成
    └── svg-maker/             # 自包含纯 SVG 图表生成
        └── references/
```

## skills —— 技能

| 路径 | 功能 |
|------|------|
| `skills/git-kit` | Git 工作流辅助工具包，按意图路由到生成 commit message、提交推送、创建/切换分支、创建/更新 PR/MR、按编号合并 PR/MR 并回主干更新、给分支打版本标签并推送、仓库瘦身、分类 star。 |
| `skills/project-insight` | 开源项目深度解读，产出每个论断都带可点开验证的真实源码引用（文件:行号），避免幻觉。 |
| `skills/tech-design-proposal` | 编写完整的技术方案或架构设计文档（含复杂度分级模板）。 |
| `skills/svg-maker` | 生成自包含、纯 SVG 的架构图、流程图与概念图，可离线打开。 |

每个 skill 目录下是一个 `SKILL.md`（含 frontmatter 定义触发条件），复杂逻辑可拆到 `references/` 子目录。`skills/` 下只放各技能的目录，不放置说明性文件（见下方"用法说明"）。

> **联动**：`skills/git-kit` 与 `commands/git/*` 命令共享同一实现，命令为委托壳，实际逻辑在 git-kit 的 `references/` 与 `scripts/` 中，二者互为两条入口（斜杠指令 / 自然语言触发）。

## commands —— 斜杠指令

`commands/` 下是与 Git 相关的自定义指令：

| 路径 | 功能 |
|------|------|
| `commands/git/branch` | 基于中文描述生成候选分支名，选择后从基准分支创建并切换 |
| `commands/git/message` | 将中文描述转换为 Conventional Commits 格式的 commit message（纯生成，不提交） |
| `commands/git/pr-create` | 基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab） |
| `commands/git/pr-merge` | 按编号合并 PR/MR，删除原分支，切回主干并更新代码（自动识别 gh/glab） |
| `commands/git/tag` | 查看最新 tag 与来源分支，选择要打 tag 的分支与版本号，构建注记 tag 并推送 |
| `commands/git/commit-push` | 基于代码变更自动生成 commit message 并执行提交推送 |
| `commands/git/slim` | 将当前 git 仓库瘦身为浅克隆，默认保留 30 天历史 |
| `commands/git/star-classify` | 拉取并分类自己的 GitHub star 仓库，输出中文分组清单 |

详见 [commands/README.md](commands/README.md)。

## 用法说明

这些命令与技能通过**软链接**注册到本机 opencode 配置目录来启用，不改动本仓库内的文件，便于后续 `git pull` 同步更新。配置目录默认为 `~/.config/opencode/`。

将本仓库路径替换到下方命令中的 `/path/to/ai-kit` 后执行：

```bash
# 软链 skills 到 opencode 的 skills 目录
ln -sfn /path/to/ai-kit/skills/* ~/.config/opencode/skills/

# 软链 commands 到 opencode 的 command 目录
ln -sfn /path/to/ai-kit/commands/git ~/.config/opencode/command/git
```

> **约定**：`skills/` 下只放各技能的目录（如 `git-kit/`），不放置说明性文件。`skills/*` 会展开全部条目，若未来在 `skills/` 新增非目录文件，会一并被软链到 skills 目录，故请保持该约定。
>
> 提示：若不希望跟随本仓库更新，也可改用复制方式（`cp -r`）；若本机已在对应位置存在**同名真实目录**，需先手动移走再由命令建立软链。

安装/卸载逻辑均只涉及本机配置目录（`~/.config/opencode/`）。`commands/README.md` 仅说明功能与用法，不重复安装步骤；本仓库的功能一览见本文档，各 skill 与指令的命名与目录结构见上文目录树。
