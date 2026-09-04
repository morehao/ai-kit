/**
 * dsh-git-commands —— 把 ai-kit 的 git-kit Git 工作流以 dsh 原生命令方式接入。
 *
 * 架构（命令 = 意图表，单一真源在 git-kit skill）：
 * - 逻辑与「意图路由」的唯一真源是 `skills/git-kit`（SKILL.md 意图决策树 +
 *   references/ + scripts/）。本插件不复制逻辑，只声明「命令 → git-kit 分支」的
 *   映射表（COMMANDS），是 dsh 斜杠侧的一条薄入口，与 opencode 的
 *   `commands-opencode/git/*.md`、自然语言触发互为入口。
 * - 每条命令注册到 ctx.commands（CommandDefinition：name/description/input.hint/
 *   handler），出现在 dsh 斜杠菜单；handler 校验必填输入后构造一条 user 消息，
 *   经 invocation.agent.followup() 注入当前会话，让 agent 按 git-kit 对应分支执行。
 * - 本模块自包含：不读取 ai-kit 仓库内任何文件、无路径耦合、不依赖
 *   @deepseek-ai/* 运行时 import（消息对象手工构造为官方 createUserMessage 的
 *   契约形状：role/source/content/id 全齐）。改 git-kit skill 无需重启；
 *   改本文件（含 COMMANDS 表）需重启 dsh web。
 *
 * git-kit 分支 key 词汇表（与 SKILL.md 决策树对齐）：
 *   commit-push / commit-message / branch / pr-create / pr-merge / tag / slim / star-classify
 */

import { randomUUID } from "node:crypto";

export const name = "dsh-git-commands";
export const inject = ["commands"];

/**
 * 命令意图表。每条 = 一行声明：注册元数据 + git-kit 分支 key。
 * `branch` 必须与 skills/git-kit/SKILL.md 决策树的分支 key 一致。
 */
const COMMANDS = [
	{
		name: "git-message",
		branch: "commit-message",
		hint: "<中文描述>",
		required: true,
		description: "将中文描述转换为 Conventional Commits 格式的 commit message（纯生成，不提交）"
	},
	{
		name: "git-commit-push",
		branch: "commit-push",
		description: "基于代码变更生成 commit message 并自动提交推送到远端；稳定分支（main/master/含 release）时自动创建分支"
	},
	{
		name: "git-branch",
		branch: "branch",
		hint: "<中文描述>",
		required: true,
		description: "基于中文描述生成候选分支名，选择后从基准分支创建并切换"
	},
	{
		name: "git-pr-create",
		branch: "pr-create",
		hint: "[目标分支]",
		description: "基于代码差异向目标仓库创建或更新 PR/MR（自动识别 gh/glab）"
	},
	{
		name: "git-pr-merge",
		branch: "pr-merge",
		hint: "[PR/MR 编号]",
		description: "按编号合并 PR/MR（自动识别 gh/glab），删除原分支，切回主干并更新代码"
	},
	{
		name: "git-tag",
		branch: "tag",
		hint: "[tag名或分支名]",
		description: "查看最新 tag 与来源分支，选择分支与版本号，构建注记 tag 并推送到远端"
	},
	{
		name: "git-slim",
		branch: "slim",
		hint: "[保留天数]",
		description: "将当前 git 仓库瘦身为浅克隆，默认保留最近 30 天历史，保留本地未提交改动"
	},
	{
		name: "git-star-classify",
		branch: "star-classify",
		description: "拉取并分类你自己的 GitHub star 仓库，输出按大类分组的中文 Markdown 清单"
	}
];

/** 构造一条 user 消息（形态与官方 createUserMessage 一致，source 必填，全深冻结）。 */
function userMessage(text) {
	return Object.freeze({
		role: "user",
		// dsh 的 Message 契约要求 source 字段（读 message.source.kind），缺失会在 agent 回合崩溃。
		source: Object.freeze({ kind: "user" }),
		content: Object.freeze([Object.freeze({ type: "text", text })]),
		id: randomUUID()
	});
}

/**
 * 构造注入当前会话的指令：告知用户请求，并把执行交给 git-kit 的对应分支。
 * git-kit 分支的完整流程（references/ 与 scripts/）由 agent 加载 skill 后自行读取，
 * 这里不复制任何逻辑，只做意图指路。
 */
function buildInstruction(def, input) {
	return [
		`【dsh 命令 /${def.name}】`,
		`用户请求：${input.length > 0 ? input : "（未附加说明，按分支流程默认处理）"}`,
		"",
		`请用 skill 工具加载 git-kit，将本次请求视为 ${def.branch} 分支并按该分支的完整流程执行。`,
		"如需用户决策（候选分支名 / PR·MR 编号 / tag 版本号 / 保留天数等），先向用户确认再继续。"
	].join("\n");
}

function makeHandler(def) {
	return (invocation) => {
		const input = invocation.rawInput.trim();
		if (def.required && input.length === 0) {
			return { kind: "error", text: `Usage: /${def.name} ${def.hint}\n例如：/${def.name} 修复登录超时` };
		}
		const instruction = buildInstruction(def, input);
		try {
			invocation.agent.followup(userMessage(instruction));
		} catch (error) {
			return {
				kind: "error",
				text: `已生成委托指令，但无法交给当前会话执行：${error instanceof Error ? error.message : String(error)}`
			};
		}
		return { kind: "success", text: `已按 git-kit ${def.branch} 分支委托执行 /${def.name}，agent 将按流程继续。` };
	};
}

export function apply(ctx) {
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
