# npm 发包流程与说明（`@morehao/dsh-commands`，OIDC / Trusted Publishing）

> 本文记录把 `commands-dsh/` 发布到 npm 的**完整流程**与**踩坑清单**。核心原则同样适用于其他 npm 包：**打 tag + OIDC 免长效 token**。文末「操作手册」是日常发新版的速查。

## 1. 总览

- **发布包**：`@morehao/dsh-commands`（源码目录 `commands-dsh/`，二者**刻意不同名**）。
- **发布模型**：打 `vX.Y.Z` tag → OIDC（Trusted Publishing）自动发布，**不需要长效 token**。
- **自动发布**：`.github/workflows/release.yml`（tag 触发）→ `scripts/ci-publish.sh`（发布逻辑）。
- **范围**：全仓仅此一个子包入 npm；`skills/` 与 `commands-opencode/` 侧**不入包**。

## 2. 日常发新版（操作手册）

1. **升版本**：改 `commands-dsh/package.json` 的 `version`（如 `0.1.0` → `0.2.0`），如有需要同步 `commands-dsh/README.md`；提交并 push 到 `main`。
2. **打 tag**（去掉 `v` 前缀，与 package.json 版本一致）：
   ```bash
   git tag v0.2.0 && git push origin v0.2.0
   ```
3. **自动发布**：workflow 收到 tag（`on: push: tags: ['v*']`）后：
   - 读 `RELEASE_TAG=v0.2.0` → 校验 `0.2.0 == commands-dsh/package.json.version`（**不一致拒绝发布**）。
   - 若 npmjs 已存在 `0.2.0` → **跳过**（幂等）。
   - 否则 OIDC：`npm publish --provenance --access public --registry https://registry.npmjs.org`。

> 提示：tag 版本与 `package.json` 版本必须一致，否则 `ci-publish.sh` 会以非零退出并阻止发布（这是防误发的守卫）。

## 3. 一次性 npm 侧设置（新建包时）

> 前置：账号 `morehao` 已开通 npm，「发布需 2FA」开启。

### 3.1 先让包「存在」于 npm（鸡生蛋）
Trusted Publisher 要求包**已存在**才能配置。用占位包建出来：

```bash
# 注意：该工具是「非交互」跑 npm publish；若账号发布需 2FA，必须用带 bypass-2FA 的 granular token：
read -s NPM_TOKEN && export NPM_TOKEN
npx --yes setup-npm-trusted-publish @morehao/dsh-commands --registry https://registry.npmjs.org
```

- 会发布一个 `0.0.0` 占位包（只用于建包，无实际功能；`dist-tags.latest` 会被它占位，正式版发布后覆盖）。
- `--registry` **必须**指向 `https://registry.npmjs.org`；本机全局 `~/.npmrc` 若是 npmmirror，会被劫持，务必显式覆盖（否则会弹 CNPM 注册页）。

### 3.2 配置 Trusted Publisher
到 `https://www.npmjs.com/package/@morehao/dsh-commands/access`：

| 字段 | 值 |
|---|---|
| Provider | GitHub Actions |
| Owner | `morehao` |
| Repository | `ai-kit` |
| **Workflow** | **`release.yml`**（文件名；且本 workflow 的 `name:` **也必须等于 `release.yml`**） |
| Environment | 留空 |
| **Allowed actions** | **必须允许 `npm publish` 直接发布**（2026-09-03 后新建的默认只允许 `npm stage publish`） |

> **关键匹配**：GitHub OIDC 的 `workflow` claim 取的是 workflow 的 `name:` 字段；而 npm 表单要的是**以 `.yml` 结尾的文件名**。二者要对得上，就把 workflow 的 `name:` 也写成 `release.yml`（否则 OIDC 只报 `E404 not found`，极难定位）。

### 3.3 可选加固
- 发布走 OIDC，无需 token；建包用的临时 bypass-2FA token 用完即撤，GitHub `NPM_TOKEN` secret 也可删除。
- 可进一步收紧包权限（Trusted Publishing 不受影响）。

## 4. 关键文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/release.yml` | `on: push: tags: ['v*']`；job 权限含 `id-token: write`；跑 `bash ./scripts/ci-publish.sh` |
| `scripts/ci-publish.sh` | 读 `RELEASE_TAG` 版本、校验 package.json、跳过已发布、OIDC 发布 |
| `commands-dsh/package.json` | 包名/版本；`publishConfig.access: public`；`dsh.bundle.patch` 指向 `cordis.patch.yml` |
| `commands-dsh/cordis.patch.yml` | 插件注册 patch：`id: dsh-commands`、`name: '@morehao/dsh-commands'` |
| `commands-dsh/lib/index.js` | `export const name = "dsh-commands"` |

## 5. dsh 插件命名约定（改包名/插件名时三处同步核对）

- `package.json` 的 `name`（npm 包名）== `cordis.patch.yml` 的 `insert[0].name`（dsh 启动时 `import()` 的**模块标识符**）。
- `lib/index.js` 的 `export const name`（cordis 插件名）== `cordis.patch.yml` 的 `insert[0].id`，与模块标识符**解耦**。
- 仓库目录名 `commands-dsh/` 与 npm 包名刻意不同（前者与 `commands-opencode/` 平行）。

## 6. 踩坑清单（排障速查）

| 症状 | 根因 | 解决 |
|---|---|---|
| pnpm `ERR_UNKNOWN_BUILTIN_MODULE` | Node < 22.13（`node:sqlite`） | CI 用 `node-version: 22` |
| publish 绿色但没发 | `@actions/exec` 不做 shell 解析，`a && b` 只执行 `a` | 用**单一命令** `bash ./scripts/ci-publish.sh` |
| `403 Two-factor … bypass 2fa` | classic `npm_` token 不能绕过 2FA | 用**带 bypass-2FA 的 granular token** |
| `npm login` 弹 CNPM/npmmirror | 全局 `~/.npmrc` registry 是 npmmirror | 一律 `--registry https://registry.npmjs.org` |
| Trusted Publisher 配不了 | 包还没在 npm 上存在 | 先 `setup-npm-trusted-publish` 发占位包 |
| OIDC `401/403` | job 缺 `id-token: write` 或设了 `NODE_AUTH_TOKEN` | 加 `id-token: write`；**不要**设 `NODE_AUTH_TOKEN`（会覆盖 OIDC） |
| OIDC `404 Not found` | workflow 名对不上 | workflow `name:` == `release.yml`（文件名） |
| OIDC `403 permission denied for this action` | Allowed actions 只允许 stage | 勾选**允许 `npm publish`**（无视「Not recommended」提示） |
| `npm view`/curl 仍显示旧版本 | npm 读端点 CDN 缓存滞后（1–2 分钟，甚至 404） | 看**单版本端点** `.../pkg/0.1.0`，稍等再确认 |
