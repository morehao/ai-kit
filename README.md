# opencode 扩展工具集 (ai-kit)

本项目集中管理我要用的 opencode 自定义扩展：一部分是 `commands/`（斜杠指令），一部分是 `skills/`（技能）。

## 目录结构

```
ai-kit/
├── README.md                  # 本说明
├── LICENSE
├── commands/                  # opencode 斜杠指令
│   ├── README.md              # 指令说明与安装
│   └── git/                   # Git 相关指令
│       ├── branch.md
│       ├── message.md
│       ├── pr.md
│       ├── slim.md
│       ├── commit-push.md
│       └── slim.md
└── skills/                    # opencode 技能
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
| `skills/project-insight` | 开源项目深度解读，产出每个论断都带可点开验证的真实源码引用（文件:行号），避免幻觉。 |
| `skills/tech-design-proposal` | 编写完整的技术方案或架构设计文档。 |
| `skills/svg-maker` | 生成自包含、纯 SVG 的架构图、流程图与概念图，可离线打开。 |

每个 skill 目录下是一个 `SKILL.md`（含 frontmatter 定义触发条件），复杂逻辑可拆到 `references/` 子目录。

## commands —— 斜杠指令

`commands/` 下是与 Git 相关的自定义指令：

| 路径 | 功能 |
|------|------|
| `commands/git/branch` | 基于中文描述生成候选分支名，选择后从基准分支创建并切换 |
| `commands/git/message` | 将中文描述转换为 Conventional Commits 格式的 commit message（纯生成，不提交） |
| `commands/git/pr` | 基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab） |
| `commands/git/commit-push` | 基于代码变更自动生成 commit message 并执行提交推送 |
| `commands/git/slim` | 将当前 git 仓库瘦身为浅克隆，默认保留 30 天历史 |

详见 [commands/README.md](commands/README.md)。

## 用法说明

这些命令与技能通过注册到 opencode 的配置目录来启用：

- **skills** 注册到 opencode 的 skills 目录（默认位于 `~/.config/opencode/skills/`）。
- **commands** 注册到 opencode 的 command 目录（默认位于 `~/.config/opencode/command/`），详见 `commands/README.md`。

本仓库本身是可 git 管理的代码仓库；是否安装、以何种方式（软链接/复制）注册到本机 `~/.config/opencode/`，由你自行决定。
