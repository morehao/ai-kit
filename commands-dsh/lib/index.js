/**
 * dsh-git-commands —— 把 ai-kit `commands-opencode/git/*` 斜杠指令以 dsh 原生命令方式接入。
 *
 * 设计（沿用 ai-kit 的「委托壳」哲学，单一真源在 ai-kit 仓库）：
 * - 每条命令注册到 ctx.commands：出现在 dsh 斜杠菜单、可声明参数 hint、可做确定性校验。
 * - 命令执行时**运行时读取** <ai-kit>/commands-opencode/git/<file>.md 正文，连同用户请求一起经
 *   invocation.agent.followup() 注入当前会话，由 agent 按 git-kit 流程执行（交互步骤照旧）。
 * - 本模块只依赖 Node 内置模块（零 @deepseek-ai/* 运行时 import），
 *   避免第三方插件对内部模块解析位置的脆弱依赖。
 */

import { readFileSync, realpathSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const name = "dsh-git-commands";
const inject = ["commands"];

/**
 * ai-kit 仓库根目录：默认按本模块真实路径上溯
 * （<root>/commands-dsh/lib/index.js -> <root>），可用 DSH_AIKIT_DIR 覆盖。
 */
function resolveAiKitRoot() {
	const override = process.env.DSH_AIKIT_DIR;
	if (override !== undefined && override.trim().length > 0) return override.trim();
	return dirname(dirname(dirname(realpathSync(fileURLToPath(import.meta.url)))));
}

/** 每条命令 = 一个 ai-kit 委托壳文件 + 菜单描述 + 参数形态。 */
const COMMANDS = [
	{ name: "git-message", file: "message.md", hint: "<中文描述>", required: true, description: "将中文描述转换为 Conventional Commits 格式的 commit message（纯生成，不提交）" },
	{ name: "git-commit-push", file: "commit-push.md", description: "基于代码变更生成 commit message 并自动提交推送到远端；稳定分支（main/master/含 release）时自动创建分支" },
	{ name: "git-branch", file: "branch.md", hint: "<中文描述>", required: true, description: "基于中文描述生成候选分支名，选择后从基准分支创建并切换" },
	{ name: "git-pr-create", file: "pr-create.md", hint: "[目标分支]", description: "基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab）" },
	{ name: "git-pr-merge", file: "pr-merge.md", hint: "[PR/MR 编号]", description: "按编号合并 PR/MR（自动识别 gh/glab），删除原分支，切回主干并更新代码" },
	{ name: "git-tag", file: "tag.md", hint: "[tag名或分支名]", description: "查看最新 tag 与来源分支，选择分支与版本号，构建注记 tag 并推送到远端" },
	{ name: "git-slim", file: "slim.md", hint: "[保留天数]", description: "将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动" },
	{ name: "git-star-classify", file: "star-classify.md", description: "拉取并分类你自己的 GitHub star 仓库，输出按大类分组的中文 Markdown 清单" }
];

/** 去掉委托壳文件开头的 YAML frontmatter，只留正文。 */
function stripFrontmatter(raw) {
	if (!raw.startsWith("---\n")) return raw.trim();
	const start = raw.indexOf("\n") + 1;
	let index = start;
	while (index <= raw.length) {
		const next = raw.indexOf("\n", index);
		const end = next < 0 ? raw.length : next;
		if (raw.slice(index, end).replace(/\r$/, "") === "---") {
			const bodyStart = next < 0 ? raw.length : next + 1;
			return raw.slice(bodyStart).trim();
		}
		if (next < 0) return raw.trim();
		index = next + 1;
	}
	return raw.trim();
}

function loadShellBody(aiKitRoot, file) {
	const shellPath = join(aiKitRoot, "commands-opencode", "git", file);
	const raw = readFileSync(shellPath, "utf8");
	return { body: stripFrontmatter(raw), shellPath };
}

/** 构造一条 user 消息（形态与 @deepseek-ai/dsh-llm createUserMessage 一致，source 必填）。 */
function userMessage(text) {
	return Object.freeze({
		role: "user",
		// dsh 的 Message 契约要求 source 字段（读 message.source.kind），缺失会在 agent 回合崩溃。
		source: Object.freeze({ kind: "user" }),
		content: [Object.freeze({ type: "text", text })],
		id: randomUUID()
	});
}

function buildInstruction(def, input, body, shellPath, aiKitRoot) {
	return [
		`【dsh 命令 /${def.name} 委托】`,
		`用户请求：${input.length > 0 ? input : "（未附加说明，按委托壳流程处理）"}`,
		"",
		`委托壳 ${relative(aiKitRoot, shellPath)} 原文如下，请按其执行：`,
		"---",
		body,
		"---",
		"说明：如需用户决策（候选分支名/PR 编号/tag 版本等），先向用户确认再继续；如委托壳要求加载 git-kit，用 skill 工具加载。"
	].join("\n");
}

function makeHandler(def) {
	return async (invocation) => {
		const input = invocation.rawInput.trim();
		if (def.required && input.length === 0) {
			return { kind: "error", text: `Usage: /${def.name} ${def.hint}\n例如：/${def.name} 修复登录超时` };
		}
		const aiKitRoot = resolveAiKitRoot();
		let shell;
		try {
			shell = loadShellBody(aiKitRoot, def.file);
		} catch (error) {
			return {
				kind: "error",
				text: `无法读取委托壳 ${def.file}（查找于 ${join(aiKitRoot, "commands-opencode", "git")}）：${error instanceof Error ? error.message : String(error)}\n可用 DSH_AIKIT_DIR 指向 ai-kit 仓库根目录。`
			};
		}
		const instruction = buildInstruction(def, input, shell.body, shell.shellPath, aiKitRoot);
		try {
			invocation.agent.followup(userMessage(instruction));
		} catch (error) {
			return { kind: "error", text: `已读取委托内容，但无法交给当前会话执行：${error instanceof Error ? error.message : String(error)}` };
		}
		return { kind: "success", text: `已按 ai-kit ${relative(aiKitRoot, shell.shellPath)} 委托 git-kit 执行 /${def.name}，agent 将按流程继续。` };
	};
}

function apply(ctx) {
	ctx.effect(function* () {
		for (const def of COMMANDS) {
			yield ctx.commands.register({
				name: def.name,
				description: def.description,
				...(def.hint === undefined ? {} : { input: { hint: def.hint } }),
				handler: makeHandler(def)
			});
		}
	}, "dsh-git-commands lifecycle");
}

export { apply, inject, name };
