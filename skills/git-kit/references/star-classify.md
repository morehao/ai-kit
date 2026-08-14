# star-classify 分支：拉取并分类 GitHub Star 仓库

本分支核心为独立脚本 `scripts/git-star.sh`（单一真源）。运行它即可拉取你 star 的所有仓库，按预设大类自动打标分类，输出一份 Markdown 清单。

## 运行方式

运行脚本 `scripts/git-star.sh`：
- 默认输出 `stars_classified.md`；`-o <文件名>` 指定输出文件，`-t <token>` 显式传 token。
- 优先使用已登录的 `gh` CLI；未安装/未登录时自动回退到 `curl + GITHUB_TOKEN`。

先运行 `bash scripts/git-star.sh`。若环境缺少认证，依据脚本输出引导：

- 未登录 gh → 提示安装并 `gh auth login`。
- 无 token → 提示跳转 GitHub settings 创建（勾选 `public_repo` / `read:user`）。

## 分类规则

- 按「大类:正则关键词」顺序匹配 topics / language / 仓库名 / description 拼接串，命中第一个即归入该类。
- 大类（表格「分类」列会以 `中文说明<br>英文大类名` 呈现）：
  - ai-ml：人工智能与机器学习
  - llm-tools：大语言模型工具
  - frontend：前端开发
  - backend：后端开发
  - mobile：移动开发
  - languages：编程语言
  - databases：数据库
  - data-science：数据分析与科学
  - devops：DevOps 与容器
  - cloud-infra：云与基础设施
  - monitoring：监控与可观测性
  - security：安全
  - cli-tools：命令行工具
  - dev-tools：开发者工具
  - ui-components：UI 组件
  - design-resources：设计资源
  - productivity：生产力与知识管理
  - browser-extensions：浏览器扩展
  - awesome-lists：精选清单
  - tutorials-courses：教程与课程
  - interview-prep：面试准备
  - books-notes：书籍与笔记
  - templates-boilerplate：模板与脚手架
- 全部未命中 → 归入 `uncategorized`（未分类）。

## 结果与应用

生成的 Markdown 按每类仓库数从多到少排序，每个分类小节是一张 5 列表格，形如：

| 仓库 | ⭐Star | 语言 | 分类 | 描述 |
| --- | --- | --- | --- | --- |
| [pytorch/pytorch](https://github.com/pytorch/pytorch) | 85321 | Python | 人工智能与机器学习<br>ai-ml | A deep learning framework<br>[needs-translation] |

- 「分类」列：`中文说明<br>英文大类名`。
- 「描述」列：`|` 与换行会被转义为 `\|` / `<br>`，避免破坏表格；中英两行在此用 `<br>` 分隔。
- 描述只有单一语言（纯中文或纯英文）时，会追加 `[needs-translation]` 标记，需按下节「翻译与回填」处理。

产出尾部附「分类统计」小表（分类 / 仓库数）。可对照表格在 GitHub 的 List 功能里把仓库手动拖入对应分类。

## 翻译与回填（模型参与）

脚本仅生成上述基础表格，不做外部翻译。`[needs-translation]` 标记出现在「描述」仅含单一语言的行：

- 纯英文描述 → 调用会话语境中的模型，补译成中文。
- 纯中文描述 → 调用模型，补译成英文（能力范围内）。
- 描述已同时含中英 → 不标记、无需处理。
- 描述为空 → 不标记。

翻译后把中英两行以 `<br>` 写回「描述」列（如 `构建 LLM 应用的框架<br>Framework for building LLM apps`），并**移除 `[needs-translation]` 标记**。无法可靠翻译的条目可保留原文与标记，不要臆造。

## 验收标准

- 生成 Markdown 文件，包含总仓库数与各分类小节，每分类条目数正确。
- 每个分类小节为 5 列表格（仓库 / ⭐Star / 语言 / 分类 / 描述），`|` 和换行已正确转义不破表。
- 「分类」列为 `中文说明<br>英文大类名`；仅有单一语言的描述带 `[needs-translation]` 标记。
- 末尾附「分类统计」小表；认证失败 / 速率限制有明确报错提示。
- 翻译回填后，描述列中英 `<br>` 两行、`[needs-translation]` 标记移除。

## 警示

- 分类由关键词规则自动判断，**不保证 100% 准确**，需人工复核后再拖入 List。
- 脚本将覆盖输出文件；默认 `stars_classified.md`，如需保留历史请用 `-o` 指定。
