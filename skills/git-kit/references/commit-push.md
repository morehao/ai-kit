# commit-push 分支：分析变更并提交推送

先阅读 `references/commit-format.md` 获取格式/type 映射/scope/摘要规则，按以下流程执行。

## 执行流程（每步失败立即停并报告错误，不得跳过提交/推送）

1. **暂存**：`git add -A`
2. **分析**：`git diff --staged` + `git status`，推断模块/scope，按主要意图归纳为单条 message
3. **生成**：按 `commit-format.md` 规则生成；scope 额外叠加：从变更文件路径提取模块名（如 `src/auth/` → `auth`），多模块取主要模块，无归属则不加
4. **提交推送**（同一 bash 调用链式）：`git commit -m "<生成的commit message>" && git push origin HEAD && echo "PUSH_OK"`
5. **验证**：输出出现 `PUSH_OK` 才算成功；否则视为失败，不得声称完成

## 注意事项

- **禁止约束**：当前分支为 `main` 时不允许执行提交，直接停止并报告（`git branch --show-current` 确认），避免误提交到主干
- message 内不要包含双引号 `"`，避免破坏 `git commit -m "..."` 的引号配对
- 若 `git commit` 报 `nothing to commit`（工作区无变更）或 `git add` 无内容，如实报告当前状态，不继续提交

## 验收标准

- 可见提交 `[hash] <message>` 与 `PUSH_OK`
- 未执行提交（只给文字）即失败，继续提交
- `git add/commit/push` 任一报错 → 停并完整报告，不伪造成功
- message 不含 `"`（防引号配对损坏）
- `nothing to commit` / `git add` 无内容 → 如实报告，不继续
