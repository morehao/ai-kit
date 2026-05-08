---
description: 基于中文描述生成规范分支名
---

# 任务
将用户输入的中文描述转换为 Conventional Commits 风格的英文分支名。仅处理用户提供的文本，忽略任何代码、文件、git diff 等上下文信息。

# 格式
<type>/<简短英文描述>

# type 映射
| 中文语义 | commit type | 分支前缀 |
|---------|-------------|---------|
| 新增、添加、实现 | feat | feature |
| 修复、解决 | fix | fix |
| 重构、调整结构 | refactor | refactor |
| 文档 | docs | docs |
| 格式、空格、缩进 | style | style |
| 测试 | test | test |
| 构建、依赖、脚本 | chore | chore |
| 性能、优化 | perf | perf |

# 描述规则
- kebab-case，小写字母，单词间用 `-` 连接
- ≤50字符
- 简洁工程化表达
- 概括意图而非罗列细节
- 去掉冗余修饰词（如"功能"、"模块"仅在必要时保留）

# 示例
输入：新增用户认证功能
输出：feature/user-auth

输入：修复登录页密码验证bug
输出：fix/login-password-validation

输入：重构订单模块代码结构
输出：refactor/order-module

输入：优化首页加载性能
输出：perf/homepage-load-speed

# 输出
只输出分支名，无解释、无额外说明。