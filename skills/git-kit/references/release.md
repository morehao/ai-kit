# release 分支：端到端发版（升版本 → 提交 → 打 tag → 推送 → 验证发布）

从「确定版本号」一路做到「远端 tag 可见 + 发布结果核实」。除版本载体（与已有 CHANGELOG）外不改任何文件。

发版**不可逆**（tag 推上去收不回，npm 同版本不可覆盖），所以：版本号 / 目标分支 / tag 名三件套**未获用户确认不得动手**，任一步失败即停在原地完整报告。

> 只打 tag、不碰仓库文件 → 走 `tag` 分支（`references/tag.md`）。

## 执行流程

1. **前置检查**
   - 工作区必须干净：`git status --porcelain` 为空；有未提交改动 → 提示先走 `commit-push` 或 stash，**不代提交**
   - 当前分支须可发布：`main`/`master`，或含 `release` 关键字的稳定分支；在 feature/fix 等分支上 → 停，询问是否先合并到主干
   - **只读探测**（在 skill 基目录下）：`bash scripts/git-release-probe.sh`（单一真源，不修改任何东西），读这些事实：
     `REMOTE` / `REMOTE_URL` / `BRANCH` / `DIRTY` / `LATEST_TAG` / `TAG_PREFIX` / `NEXT`（patch minor major 三档）/ `FILE <路径> <版本>` / `VERSION_CONSISTENT` / `NPM_PACKAGE` / `NPM_PRIVATE` / `WORKFLOW <文件> <tag 模式>`
   - 同步远端：`git fetch <REMOTE> --tags`
2. **确定版本号**（未确认前不改文件、不打 tag）
   - 用户已给（`$1` 或消息中版本号，如 `v1.2.0`、`1.2.0`，或 `--patch`/`--minor`/`--major`）→ 按 `TAG_PREFIX` 规范化（无 tag 时默认 `v` 前缀），得 `tag = <前缀><X.Y.Z>`
   - 未给 → 用 `NEXT` 展示 patch / minor / major 三档让用户选，用户也可自定义（如 `v1.3.0-beta.1`）；**不凭 commit 内容替用户猜该升哪一档**
   - 版本文件当前值已是 semver 时，新版本须严格大于它；否则提示用户确认（可能是回退或改名）
   - **校验不冲突**：`git tag -l <tag>` 与 `git ls-remote --tags <REMOTE> <tag>` 均须无输出；冲突 → 提示换名，**不覆盖已有 tag**
3. **确定要改的版本文件**
   - `VERSION_CONSISTENT=no` → **停**，把所有 `FILE <路径> <版本>` 摆给用户，让其裁决哪个是基准版本；裁决前不改任何文件
   - `FILE <路径> <no-version>`（如 private 根 `package.json` 无 `version` 字段）不算版本载体，不进改动清单
   - `FILE <none>` 或探测不到任何版本载体 → 要求用户指明版本文件，**不擅自新建** `VERSION`/`package.json`
   - 改动清单 = 每个版本文件「旧值 → 新值」（新值 = tag 去前缀的 `X.Y.Z`）
4. **CHANGELOG（仅当仓库已有）**
   - 有 `CHANGELOG.md`（或 `CHANGELOG*`）→ 按其**既有格式**（版本标题写法、日期格式、条目分组）在**文件顶部**插入新版本条目；条目来自 `git log --oneline <上一 tag>..HEAD`，按 Conventional Commits type 归纳成要点，**不逐条粘贴提交标题**
   - 无 CHANGELOG → **不新建**（宁轻勿重），确认信息里写明「无 CHANGELOG，跳过」
5. **确认（必须停一次）**：把下面整块展示给用户，等「是 / 否 / 自定义版本号」：
   ```
   发版确认
   版本：v0.1.1 → v0.2.0
   tag ：v0.2.0 → <REMOTE>/<branch> 最新提交 <sha> <subject>
   版本文件：commands-dsh/package.json 0.1.1 → 0.2.0
   CHANGELOG：无 → 跳过
   落地方式：主干直提（或 release/<version> 分支 + PR）
   提交信息：chore(release): 0.2.0
   ```
   - 目标提交取自 `git rev-parse <REMOTE>/<branch>`（已 fetch），tag 必须指向它
6. **落地方式**（在确认块里一并选定；仓库未显式要求 PR 时默认「主干直提」）
   - **主干直提**（默认，适合个人仓库，与 `PUBLISHING.md` 手册一致）：
     编辑版本文件（+ CHANGELOG）→ `git add -A` → `git commit -m "chore(release): <版本>"` → `git push <REMOTE> HEAD && echo "PUSH_OK"`
   - **release 分支 + PR**（主干受保护/团队协作时）：`git switch -c release/<version> <REMOTE>/<branch>` → 改文件 → 提交推送 → 按 `references/pr-create.md` 创建 PR → 经用户确认后按 `references/pr-merge.md` 合并 → `git switch <branch> && git pull --ff-only <REMOTE> <branch>` 回到主干最新
   - 提交信息按 `commit-format.md`（`chore(release): <版本>`），不含双引号
7. **打 tag 并推送**（同一 bash 链式，防半途；规则同 `references/tag.md`）：
   `git fetch <REMOTE> --tags && git tag -a <tag> -m "release: <tag>" <REMOTE>/<branch> && git push <REMOTE> <tag> && echo "TAG_PUSH_OK"`
   - 只打**注记 tag**（`-a`）；tag 指向 `<REMOTE>/<branch>` 的远端最新提交
   - 重新 `fetch` 再打，确保 tag 落在刚 push 的版本提交上
8. **验证发布**（给原始证据，不臆测）
   - **一致性守卫**：tag 去 `v` == 版本文件新值；不等 → 立刻报告（本仓库 `scripts/ci-publish.sh` 会以非零退出拒绝发布）
   - **CI 流水线**：探测到 `WORKFLOW <文件> <tag 模式>`（tag 触发）时 → GitHub `gh run list --workflow <文件> --limit 3`、GitLab `glab ci list`，看该 tag 触发的运行；工具不可用或无 CI → 如实写「流水线需自行查看」
   - **npm 包**（`NPM_PACKAGE` 非空且 `NPM_PRIVATE=no`）：查**单版本端点** `curl -s https://registry.npmjs.org/<pkg>/<version>`（或 `npm view <pkg>@<version> version --registry https://registry.npmjs.org`）。列表端点/`npm view <pkg> version` 有 CDN 缓存滞后（1–2 分钟），不要据它判失败
   - 输出发版报告：版本 / tag / 提交 sha / 分支 / 远端 tag 可见性 / 流水线或 registry 验证结果（含原始输出）

## 注意事项

- **三件套先确认**：版本号、目标分支、tag 名；未确认不得改文件、提交或打 tag
- **只改版本载体**：仅探测到的版本文件（与已有 CHANGELOG），不夹带功能改动，不动其他文件
- **tag 版本必须等于版本文件新值**：不一致就别打了，先修一致（CI 侧同样会拒）
- tag 已存在（本地或远端）→ 停并报告，不覆盖、不伪造成功
- 与 `tag` 分支的分工：`tag` 只打 tag、不碰文件；`release` = 升版本 + 提交 + 打 tag + 验证发布
- 验证要区分「尚未可见」与「发布失败」：CDN 缓存、流水线排队都会滞后，报告原始输出与时间点，不下结论性判断

## 验收标准

- 版本文件已实际修改且可核对（重新读文件或 `git show`，旧值 → 新值与确认块一致），提交推送输出 `PUSH_OK`
- 本地与远端均可见 tag：`git ls-remote --tags <REMOTE> <tag>` 有输出，且链式命令输出 `TAG_PUSH_OK`
- tag 版本 == 版本文件新值；当前分支回到主干且 `git status --porcelain` 为空
- 只列候选/只给文字而未真正改文件、提交或打 tag 即失败，继续执行
- 发布验证有原始证据（流水线状态或 registry 查询输出）；拿不到证据时如实标注「未验证」，不得声称已发布
- 任一步报错（权限/网络/tag 冲突/分支不存在/CI 失败）→ 停在当前状态完整报告原始报错，不伪造成功
