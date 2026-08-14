---
description: 将中文描述转换为 Conventional Commits 格式的英文 commit message（纯生成，不提交）
---

# 任务
将用户输入的中文描述转换为 Conventional Commits 格式的英文 commit message。仅处理用户提供的文本，忽略任何代码、文件、git diff 等上下文信息。

> 注意：本命令只返回 message 文字，不执行任何 git 操作。若需要分析当前代码变更并**真正提交推送**，请使用 `/git/commit-push`。

# 格式
<type>(可选scope): <摘要>

# type 映射
| 中文语义 | type |
|---------|------|
| 新增、添加、实现 | feat |
| 修复、解决 | fix |
| 重构、调整结构 | refactor |
| 文档 | docs |
| 格式、空格、缩进 | style |
| 测试 | test |
| 构建、依赖、脚本 | chore |
| 性能、优化 | perf |

# scope 推断
- 从描述中抽象涉及的功能模块（如"登录页面密码验证" → scope 为 `auth` 或 `login`）
- 描述不明确涉及某个模块时不加 scope
- 多模块时取主要变化所属模块，否则省略 scope

# 摘要规则
- 祈使句，动词原形开头
- 无句号，≤72字符，首字母小写（专有名词除外）
- 简洁工程化表达
- 概括变更意图而非罗列细节

# 示例
输入：修复了登录页面密码验证失败的问题
输出：fix(auth): fix password validation on login page

输入：新增了用户导出数据的功能
输出：feat(user): add data export feature

输入：重构了订单模块的代码结构
输出：refactor(order): restructure code architecture

# 输出
只输出 commit message，无解释、无额外说明。
