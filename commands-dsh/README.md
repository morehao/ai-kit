# dsh-git-commands

把 ai-kit 的 git-kit Git 工作流以 **dsh 原生斜杠命令**接入 dsh（与 opencode 入口、自然语言入口共用 git-kit 同一实现，单一真源）。

## 提供的命令

| 命令 | 参数 | 委托的 git-kit 分支 |
|---|---|---|
| `/git-message` | `<中文描述>`（必填） | commit-message |
| `/git-commit-push` | 无 | commit-push |
| `/git-branch` | `<中文描述>`（必填） | branch |
| `/git-pr-create` | `[目标分支]` | pr-create |
| `/git-pr-merge` | `[PR/MR 编号]` | pr-merge |
| `/git-tag` | `[tag名或分支名]` | tag |
| `/git-slim` | `[保留天数]` | slim |
| `/git-star-classify` | 无 | star-classify |

## 原理（命令 = 意图表）

每条 dsh 命令注册到 `ctx.commands`（`name`/`description`/`input.hint`/`handler`，即 `CommandDefinition`），出现在 dsh 斜杠菜单。`COMMANDS` 表是**自包含的意图表**：一行声明 = 注册元数据 + 对应的 git-kit 分支 key，**不再读取任何仓库文件**，逻辑与路由唯一真源在 `skills/git-kit`（`SKILL.md` 意图决策树 + `references/` + `scripts/`）。

命令执行时 handler 校验必填输入，然后构造一条 user 消息经 `invocation.agent.followup()` 注入当前会话，由 agent 加载 `git-kit` 并落到对应分支执行——交互确认步骤与自然语言触发 git-kit 完全一致。

- 编辑 `skills/git-kit/` 的内容**无需重启**，下次执行即生效。
- 修改本插件的 `lib/index.js`（含 `COMMANDS` 表）需重启 dsh web 生效。

## 安装（见仓库根 README「dsh 接入」）

```bash
./scripts/dsh-install.sh
# 重启 dsh web
```

## 开发

- 增删命令：改 `lib/index.js` 的 `COMMANDS` 表即可（每条一行声明）；`branch` 值必须与 git-kit `SKILL.md` 决策树的分支 key 一致。
- 命令与 opencode 侧 `commands-opencode/git/*.md` 是同一 git-kit 的两条入口，只声明意图、不重复逻辑。
