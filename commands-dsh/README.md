# dsh-git-commands

把 `ai-kit/commands-opencode/git/*` 的斜杠指令以 **dsh 原生命令**形式接入 dsh（与 opencode 入口共用同一套委托壳与 git-kit 逻辑，单一真源）。

## 提供的命令

| 命令 | 参数 | 功能（委托 git-kit 分支） |
|---|---|---|
| `/git-message` | `<中文描述>`（必填） | commit-message |
| `/git-branch` | `<中文描述>`（必填） | branch |
| `/git-commit-push` | 无 | commit-push |
| `/git-pr-create` | `[目标分支]` | pr-create |
| `/git-pr-merge` | `[PR/MR 编号]` | pr-merge |
| `/git-tag` | `[tag名或分支名]` | tag |
| `/git-slim` | `[保留天数]` | slim |
| `/git-star-classify` | 无 | star-classify |

## 原理

命令本身是 dsh 原生命令（JS 插件注册于 `ctx.commands`）。执行时**运行时读取**
`<ai-kit>/commands-opencode/git/<file>.md` 正文，连同用户请求一起注入当前会话（`agent.followup`），
由 agent 按委托壳要求加载 `git-kit` skill 并落到对应分支执行——交互确认步骤与自然语言触发 git-kit 完全一致。

- 编辑 `ai-kit` 内的委托壳 / `skills/git-kit/references/` **无需重启**，下次执行即生效。
- 修改本插件的 `lib/index.js` 需重启 dsh web 生效。

## 安装（见仓库根 README「dsh 接入」）

```bash
./scripts/dsh-install.sh
# 重启 dsh web
```

## 开发

- 增删命令：改 `lib/index.js` 的 `COMMANDS` 表即可（每条一行声明）。
- ai-kit 根目录定位：默认按插件真实路径上溯；可用环境变量 `DSH_AIKIT_DIR` 覆盖。
