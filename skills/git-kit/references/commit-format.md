# commit 格式（commit-push 与 commit-message 共用）

<type>(可选scope): <摘要>

## type 映射

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

## scope 推断

- 从描述/变更中抽象涉及的功能模块（如"登录页面密码验证" → scope 为 `auth` 或 `login`）
- 描述/变更不明确涉及某个模块时不加 scope
- 多模块时取主要变化所属模块，否则省略 scope

## 摘要规则

- 祈使句，动词原形开头
- 无句号，≤72 字符，首字母小写（专有名词除外）
- 简洁工程化表达
- 概括变更意图而非罗列细节
- 不含双引号 `"`

## 示例

| 输入/意图 | 输出 |
|-----------|------|
| 修复登录页密码验证失败 | `fix(auth): fix password validation on login page` |
| 新增用户导出数据功能 | `feat(user): add data export feature` |
| 重构订单模块代码结构 | `refactor(order): restructure code architecture` |
