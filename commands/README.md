# opencode 指令集

本目录存放 opencode 自定义指令，通过软链接注册到 `~/.config/opencode/command/` 下。

## Git 指令

| 路径 | 功能 |
|------|------|
| `git/branch-name` | 将中文描述转换为 Conventional Commits 风格的分支名 |
| `git/commit` | 将中文描述转换为 Conventional Commits 格式的 commit message |
| `git/smart-commit` | 基于代码变更自动生成 commit message 并执行提交推送 |

### 使用方式

在 opencode 对话中输入斜杠命令调用：

- `/git/branch-name <中文描述>` → 生成分支名
- `/git/commit <中文描述>` → 生成 commit message
- `/git/smart-commit` → 分析当前变更自动提交

## 安装软链接

在 opencode 配置目录下创建指向本项目的软链接：

```bash
# 将 /path/to/ai-kit 替换为实际 clone 路径
ln -sfn /path/to/ai-kit/commands/git ~/.config/opencode/command/git
```
