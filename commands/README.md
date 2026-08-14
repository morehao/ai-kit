# opencode 指令集

本目录存放 opencode 自定义指令，通过软链接注册到 `~/.config/opencode/command/` 下。

## Git 指令

| 路径 | 功能 |
|------|------|
| `git/branch` | 基于中文描述生成候选分支名，选择后从基准分支创建并切换 |
| `git/message` | 将中文描述转换为 Conventional Commits 格式的 commit message（纯生成，不提交） |
| `git/pr` | 基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab） |
| `git/commit-push` | 基于代码变更自动生成 commit message 并执行提交推送 |
| `git/slim` | 将当前 git 仓库瘦身为浅克隆，默认保留 30 天历史 |

这些 Git 指令均为**委托壳**：加载 `git-kit` skill 并落到对应分支执行，逻辑单一真源在 `skills/git-kit/references/` 与 `skills/git-kit/scripts/`，避免重复漂移。

| 指令 | 委托的 skill 分支 |
|------|-------------------|
| `git/branch` | `git-kit` branch |
| `git/message` | `git-kit` commit-message |
| `git/pr` | `git-kit` pr |
| `git/commit-push` | `git-kit` commit-push |
| `git/slim` | `git-kit` slim |

### 使用方式

在 opencode 对话中输入斜杠命令调用：

- `/git/branch <中文描述>` → 生成候选分支名，选择后创建并切换
- `/git/message <中文描述>` → 生成 commit message
- `/git/pr [目标分支]` → 基于差异创建/更新 PR/MR（默认探测 main/master）
- `/git/commit-push` → 分析当前变更自动提交并推送
- `/git/slim [天数]` → 瘦身当前仓库（默认保留 30 天历史）

## 安装软链接

在 opencode 配置目录下创建指向本项目的软链接：

```bash
# 将 /path/to/ai-kit 替换为实际 clone 路径
ln -sfn /path/to/ai-kit/commands/git ~/.config/opencode/command/git
```
