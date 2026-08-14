---
description: 基于中文描述生成候选分支名，选择后从基准分支创建并切换
---

# 任务
基于用户输入的中文描述，生成 3 个 Conventional Commits 风格的英文候选分支名，让用户选择其一；再根据用户选定的基准分支，**真正创建并切换到**该新分支。仅处理用户提供的文本，忽略任何代码、文件、git diff 等上下文信息。

# 执行流程（每步失败立即停止并报告错误，不得跳过创建/切换）

## 1. 确定基准分支
先让用户选择从哪个基准创建新分支：
- 默认 A：远端最新 `main`/`master`（探测 `origin/main` 与 `origin/master` 哪个存在；若当前本地对应分支非最新则先 `git pull origin <base>` 对齐最新）
- 选项 B：当前分支

## 2. 生成候选分支名（3 个）
基于用户传入的描述，生成 3 个风格/粒度各异的候选名，编号 1/2/3。遵循下方「格式」「type 映射」「候选规则」与「描述规则」，但三个候选表达不同（如 `feature/user-auth`、`feature/add-user-authentication`、`feature/login-secure-access`）。

## 3. 用户选择分支名
请用户输入 1/2/3 选定一个候选名。

## 4. 创建并切换分支
在**同一个 bash 调用**中链式执行切换，选定的候选名记为 `<branchname>`：
- 基准 A（远端 main/master，设基准为 `<base>`）：
  ```
  git fetch origin && git pull origin <base> && git switch -c <branchname> && echo "SWITCH_OK"
  ```
- 基准 B（当前分支）：
  ```
  git switch -c <branchname> && echo "SWITCH_OK"
  ```

## 5. 验证
确认链式命令输出中出现了 `SWITCH_OK`，且 `git branch --show-current` 为 `<branchname>`。未出现 = 任务失败，不得声称完成。

# 格式
<type>/<简短英文描述>

# type 映射
| 中文语义 | 分支前缀 |
|---------|---------|
| 新增、添加、实现 | feature |
| 修复、解决 | fix |
| 重构、调整结构 | refactor |
| 文档 | docs |
| 格式、空格、缩进 | style |
| 测试 | test |
| 构建、依赖、脚本 | chore |
| 性能、优化 | perf |

# 候选规则
- 三个候选需风格/粒度不同（如简洁型 `feature/user-auth`、展开型 `feature/add-user-authentication`、侧重实现点型 `feature/login-secure-access`）
- 均遵循下方「描述规则」
- 不与仓库已有分支冲突（可先 `git branch --list` / `git branch -r` 核对，冲突则换名）

# 描述规则
- kebab-case，小写字母，单词间用 `-` 连接
- ≤50字符
- 简洁工程化表达
- 概括意图而非罗列细节
- 去掉冗余修饰词（如"功能"、"模块"仅在必要时保留）

# 示例
输入：新增用户认证功能
候选：1. feature/user-auth  2. feature/add-user-authentication  3. feature/login-secure-access

输入：修复登录页密码验证bug
候选：1. fix/login-password-validation  2. fix/auth-password-check  3. fix/login-form-security

输入：重构订单模块代码结构
候选：1. refactor/order-module  2. refactor/order-code-structure  3. refactor/order-domain

输入：优化首页加载性能
候选：1. perf/homepage-load-speed  2. perf/index-page-performance  3. perf/front-page-render

# 验收标准
- 必须看到切换成功的输出、最终 `git branch --show-current` 为选定的新分支名，并出现 `SWITCH_OK`
- 未真正创建并切换（仅列出了候选名）即视为失败，继续执行
- 若分支已存在、`git pull` 失败、`git switch` 报错等任一错误，立即停止并完整报告错误输出，不跳到下一步，不得伪造成功
