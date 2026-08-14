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
- 大类：ai-ml、llm-tools、frontend、backend、mobile、languages、databases、data-science、devops、cloud-infra、monitoring、security、cli-tools、dev-tools、ui-components、design-resources、productivity、browser-extensions、awesome-lists、tutorials-courses、interview-prep、books-notes、templates-boilerplate。
- 全部未命中 → 归入 `uncategorized`。

## 结果与应用

生成的 Markdown 按每类仓库数从多到少排序，每行形如：
`- [owner/repo](html_url) ⭐stars — description`

可对照该清单在 GitHub 的 List 功能里把仓库手动拖入对应分类。

## 验收标准

- 生成 Markdown 文件，包含总仓库数与各分类小节，每分类条目数正确。
- 输出末尾有分类结果统计。
- 认证失败 / 速率限制有明确报错提示。

## 警示

- 分类由关键词规则自动判断，**不保证 100% 准确**，需人工复核后再拖入 List。
- 脚本将覆盖输出文件；默认 `stars_classified.md`，如需保留历史请用 `-o` 指定。
