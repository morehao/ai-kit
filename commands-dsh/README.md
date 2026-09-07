# dsh-commands

一个可扩展的 **dsh 原生斜杠命令集合包**（npm 名 `@morehao/dsh-commands`，仓库目录仍为 `commands-dsh/`）。当前内置 git-kit 的 Git 工作流命令（与 opencode 入口、自然语言入口共用 git-kit 同一实现，单一真源）；将来其它 skill 的命令只需往 `lib/index.js` 的 `COMMANDS` 表加条目即可。

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

## 安装

本插件已发布到 npm（`@morehao/dsh-commands`），可通过 dsh 一条命令安装：

```bash
# 从 npm 安装已发布版本（git-kit skill 仍需由 ai-kit 提供，见下方说明）
dsh plugin --profile web add @morehao/dsh-commands
# 重启 dsh web
```

> **skill 依赖**：插件只声明「命令 → git-kit 分支」意图表，真正的执行授权给 `git-kit` skill。而 dsh 不从 node_modules 扫描 skill，所以仍需把 `skills/git-kit/` 放入 `$DSH_HOME/skills`（默认 `~/.dsh/skills`）。完整一键接入见仓库根 `./scripts/dsh-install.sh`，它同时软链 `skills/*` 并以 `link:`（开发模式，源码改动即生效）方式接入本插件。

本地开发 / 测试用 `link:` 方式（源码即时生效）：

```bash
./scripts/dsh-install.sh
# 重启 dsh web
```

## 开发

- 增删命令：改 `lib/index.js` 的 `COMMANDS` 表即可（每条一行声明）；`branch` 值必须与 git-kit `SKILL.md` 决策树的分支 key 一致。
- 命令与 opencode 侧 `commands-opencode/git/*.md` 是同一 git-kit 的两条入口，只声明意图、不重复逻辑。

## 发布（自动）

用**打 tag** 自动发布到 npm（OIDC / Trusted Publishing，无需长效 token；见仓库根 `.github/workflows/release.yml`）：

- 发布方式：升好版本后打 tag 并推送，workflow 用 OIDC 把该版本发布到 npmjs：
  ```bash
  # 1) 升版本：改 commands-dsh/package.json 的 version（如 0.1.0 -> 0.2.0），提交并 push 到 main
  # 2) 打与版本一致的 tag（去掉 v 前缀）：git tag v0.2.0 && git push origin v0.2.0
  ```
  workflow 会校验 `tag 版本 == package.json version`（不一致拒绝发布）；同版本在 npm 已存在则跳过（幂等）。
- **关键约定**：`package.json` 的 `name`（npm 包名）与 `cordis.patch.yml` 的 `insert[0].name`（dsh 启动时 `import()` 的**模块标识符**）必须一致；`lib/index.js` 的 `export const name`（cordis 插件名）与 `cordis.patch.yml` 的 `insert[0].id` 保持一致即可，但与模块标识符解耦。改包名时请三者同步核对。
