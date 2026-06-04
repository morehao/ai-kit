---
description: 基于代码变更自动生成 commit message
---

# 任务
分析当前待提交的代码变更（git diff），理解改动意图，生成符合 Conventional Commits 规范的英文 commit message。

# 分析流程
1. 运行 `git add -A` 将所有变更（新增、修改、删除）加入暂存区
2. 运行 `git diff --staged` 查看暂存区变更
3. 结合 `git status` 了解变更文件列表，推断涉及的模块/scope
4. 根据变更内容的语义判断 type（新增功能、修复bug、重构等）
5. 综合所有变更提炼一条简洁的 commit message；若变更横跨多个关注点，按主要意图归纳，不拆分为多条

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
- 从变更文件路径提取模块名（如 `src/auth/` → scope 为 `auth`）
- 多模块变更时取主要变更所属模块；无明确模块归属时不加 scope

# 摘要规则
- 祈使句，动词原形开头
- 无句号，≤72字符，首字母小写（专有名词除外）
- 简洁工程化表达
- 概括变更意图而非罗列细节

# 输出
1. 只输出 commit message，无解释、无额外说明
2. commit message 生成后，自动执行：
   git commit -m "<生成的commit message>"
   git push origin HEAD