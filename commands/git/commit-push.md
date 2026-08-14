---
description: 基于代码变更生成 commit message 并自动提交推送到远端
---

# 任务
分析当前待提交的代码变更（git diff），生成一条符合 Conventional Commits 规范的英文 commit message，并**真正执行提交与推送**。与「message」不同，本命令的交付物是已完成提交推送的结果，而非仅一段文字。

# 执行流程（每步失败立即停止并报告错误，不得跳过提交/推送）

## 1. 暂存变更
运行 `git add -A` 将所有变更（新增、修改、删除）加入暂存区。

## 2. 分析变更
- 运行 `git diff --staged` 查看暂存区变更
- 结合 `git status` 了解变更文件列表，推断涉及的模块/scope
- 根据变更内容的语义判断 type（新增功能、修复bug、重构等）
- 综合所有变更提炼一条简洁的 commit message；若变更横跨多个关注点，按主要意图归纳，不拆分为多条

## 3. 生成 commit message
按 `message` 命令（`/git/message`）中的「格式」「type 映射」「scope 推断」「摘要规则」生成一条 message。注意：message 仅是执行的前置产物，**不是最终输出**。

commit-push 在 message 规则基础上，scope 采取如下推断（叠加于 message 的 scope 规则）：
- 从变更文件路径提取模块名（如 `src/auth/` → scope 为 `auth`）
- 多模块变更时取主要变更所属模块；无明确模块归属时不加 scope

# 摘要规则
- 祈使句，动词原形开头
- 无句号，≤72字符，首字母小写（专有名词除外）
- 简洁工程化表达
- 概括变更意图而非罗列细节
- 不含双引号 `"`

## 4. 提交并推送
在**同一个 bash 调用**中链式执行以下命令：

```
git commit -m "<生成的commit message>" && git push origin HEAD && echo "PUSH_OK"
```

## 5. 验证
确认链式命令输出中出现了 `PUSH_OK`。未出现 = 任务失败，不得声称完成。

# 验收标准
- 必须看到提交成功的 `[hash] <message>` 输出与 `PUSH_OK` 才算成功
- 未执行提交（仅输出了 message 文字）即视为失败，继续执行提交
- 若 `git add` / `git commit` / `git push` 任一命令报错，立即停止并完整报告错误输出，不跳到下一步，不得伪造成功

# 注意事项
- message 内不要包含双引号 `"`，避免破坏 `git commit -m "..."` 的引号配对
- 若 `git commit` 报 `nothing to commit`（工作区无变更）或 `git add` 无内容，如实报告当前状态，不继续提交