# opencode 技能集

本目录存放 opencode 自定义技能（`SKILL.md`），安装方式见根目录 `README.md`。

## 技能列表

| 路径 | 功能 |
|------|------|
| `git-kit` | Git 工作流辅助工具包，按意图路由到生成 commit message、提交推送、创建/切换分支、创建/更新 PR/MR、仓库瘦身、分类 star。 |
| `project-insight` | 开源项目深度解读，产出每个论断都带可点开验证的真实源码引用（文件:行号），避免幻觉。 |
| `tech-design-proposal` | 编写完整的技术方案或架构设计文档（含复杂度分级模板）。 |
| `svg-maker` | 生成自包含、纯 SVG 的架构图、流程图与概念图，可离线打开。 |

## 与 commands 的联动

`skills/git-kit` 与 `commands/git/*` 命令直接联动：命令是**委托壳**，加载 `git-kit` 后落到对应分支执行，逻辑单一真源在 `git-kit/references/` 与 `git-kit/scripts/`，避免重复漂移。参见 [commands/README.md](../commands/README.md)。
