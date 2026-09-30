/** Subscription quotas, not API RPM/TPM limits. Credentials stay in memory.
 * Endpoint references:
 * https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift
 * https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift
 */
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const POLL_MS = 120_000;
const TIMEOUT_MS = 10_000;
const WIDTH = 8;
const ENDPOINTS = {
	openai: "https://chatgpt.com/backend-api/wham/usage",
	anthropic: "https://api.anthropic.com/api/oauth/usage",
} as const;
type Provider = keyof typeof ENDPOINTS;
export type Quota = { label: string; percent: number; resetAt?: number };
type State = {
	quotas: Quota[];
	error?: string;
	nextAt: number;
	retryAt: number;
	pending?: Promise<void>;
};

type Json = Record<string, unknown>;
function object(value: unknown): Json {
	return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Json : {};
}
function number(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}
function quota(label: string, percent: unknown, reset: unknown): Quota | undefined {
	const used = number(percent);
	if (used === undefined || used < 0) return undefined;
	const timestamp = typeof reset === "string" ? Date.parse(reset) : (number(reset) ?? 0) * 1000;
	return {
		label,
		percent: Math.min(100, used),
		resetAt: Number.isFinite(timestamp) && timestamp > 0 ? timestamp : undefined,
	};
}

export function parseQuotas(provider: Provider, data: unknown): Quota[] {
	const body = object(data);
	if (provider === "anthropic") {
		return [["5h", "five_hour"], ["7d", "seven_day"]].flatMap(([label, key]) => {
			const window = object(body[key]);
			const parsed = quota(label, window.utilization, window.resets_at);
			return parsed ? [parsed] : [];
		});
	}
	const limits = object(body.rate_limit);
	return [["primary", "primary_window"], ["secondary", "secondary_window"]].flatMap(([fallback, key]) => {
		const window = object(limits[key]);
		const seconds = number(window.limit_window_seconds);
		const label = seconds && seconds > 0
			? seconds >= 86400 ? `${Math.round(seconds / 86400)}d` : `${Math.round(seconds / 3600)}h`
			: fallback;
		const parsed = quota(label, window.used_percent, window.reset_at);
		return parsed ? [parsed] : [];
	});
}

export function accountId(token: string): string | undefined {
	try {
		const payload = object(JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString()));
		const id = object(payload["https://api.openai.com/auth"]).chatgpt_account_id;
		return typeof id === "string" && id.length > 0 ? id : undefined;
	} catch {
		return undefined;
	}
}

export function formatReset(resetAt: number | undefined, now = Date.now()): string {
	if (resetAt === undefined) return "";
	const minutes = Math.ceil((resetAt - now) / 60_000);
	if (minutes <= 0) return "now";
	if (minutes < 60) return `${minutes}m`;
	if (minutes < 1440) return `${Math.floor(minutes / 60)}h${minutes % 60 ? `${minutes % 60}m` : ""}`;
	return `${Math.floor(minutes / 1440)}d${Math.floor(minutes % 1440 / 60)}h`;
}

export function overlayParts(percent: number | undefined, label: string, width = WIDTH): { filled: string; remaining: string } {
	const clipped = label.slice(0, width);
	const text = " ".repeat(Math.floor((width - clipped.length) / 2)) + clipped;
	const padded = text.padEnd(width, " ");
	const used = percent !== undefined && Number.isFinite(percent) ? Math.max(0, Math.min(100, percent)) : 0;
	const filled = Math.min(width, Math.max(used > 0 ? 1 : 0, Math.round(used / 100 * width)));
	return { filled: padded.slice(0, filled), remaining: padded.slice(filled) };
}

export function retryAt(value: string | null, now = Date.now()): number {
	const seconds = value === null ? NaN : Number(value);
	const requested = Number.isFinite(seconds) ? now + seconds * 1000 : Date.parse(value ?? "");
	return Math.max(now + 300_000, Number.isFinite(requested) ? requested : 0);
}

export type GitStatus = {
	branch: string;
	upstream: boolean;
	unborn: boolean;
	staged: number;
	modified: number;
	untracked: number;
	conflicts: number;
	ahead: number;
	behind: number;
	stash: number;
};

export function parseGitStatus(output: string): GitStatus {
	const status: GitStatus = {
		branch: "", upstream: false, unborn: false,
		staged: 0, modified: 0, untracked: 0, conflicts: 0, ahead: 0, behind: 0, stash: 0,
	};
	const records = output.split("\0");
	for (let index = 0; index < records.length; index++) {
		const record = records[index];
		if (record.startsWith("# branch.head ")) status.branch = record.slice(14);
		else if (record.startsWith("# branch.upstream ")) status.upstream = true;
		else if (record === "# branch.oid (initial)") status.unborn = true;
		else if (record.startsWith("# branch.ab ")) {
			const match = record.match(/^# branch\.ab \+(\d+) -(\d+)$/);
			if (match) { status.ahead = Number(match[1]); status.behind = Number(match[2]); }
		} else if (record.startsWith("# stash ")) status.stash = Number(record.slice(8)) || 0;
		else if (record.startsWith("? ")) status.untracked++;
		else if (record.startsWith("u ")) status.conflicts++;
		else if (record.startsWith("1 ") || record.startsWith("2 ")) {
			const [, xy, submodule] = record.split(" ", 3);
			if (xy[0] !== ".") status.staged++;
			if (xy[1] !== "." || (submodule[0] === "S" && submodule.slice(2) !== "..")) status.modified++;
			// Renames/copies have a second NUL-delimited record containing the original path.
			if (record[0] === "2") index++;
		}
	}
	if (!status.branch) throw new Error("Invalid git status");
	if (status.branch === "(detached)") status.branch = "detached";
	return status;
}

export function gitIndicators(status: GitStatus): Array<{ color: "success" | "warning" | "error" | "muted" | "accent"; text: string }> {
	const indicators: ReturnType<typeof gitIndicators> = [];
	if (status.staged) indicators.push({ color: "success", text: `+${status.staged}` });
	if (status.modified) indicators.push({ color: "warning", text: `~${status.modified}` });
	if (status.untracked) indicators.push({ color: "muted", text: `?${status.untracked}` });
	if (status.conflicts) indicators.push({ color: "error", text: `!${status.conflicts}` });
	if (!indicators.length) indicators.push({ color: "success", text: "✓" });
	if (status.ahead) indicators.push({ color: "accent", text: `↑${status.ahead}` });
	if (status.behind) indicators.push({ color: "warning", text: `↓${status.behind}` });
	if (!status.upstream) indicators.push({ color: "muted", text: "∅" });
	if (status.stash) indicators.push({ color: "accent", text: `≡${status.stash}` });
	if (status.unborn) indicators.push({ color: "muted", text: "new" });
	return indicators;
}

const execGit = promisify(execFile);
export async function queryGitStatus(cwd: string, signal: AbortSignal): Promise<GitStatus> {
	const { stdout } = await execGit("git", [
		"--no-optional-locks", "status", "--porcelain=v2", "--branch", "--show-stash", "--untracked-files=all", "-z",
	], { cwd, signal, timeout: 3000, maxBuffer: 4 * 1024 * 1024, encoding: "utf8" });
	return parseGitStatus(stdout);
}

async function piToken(ctx: ExtensionContext, provider: string): Promise<string | undefined> {
	const model = ctx.modelRegistry.getAll().find((model) => model.provider === provider);
	if (!model || !ctx.modelRegistry.isUsingOAuth(model)) return undefined;
	// Pi owns refresh and locking; never refresh or rewrite CLI credentials ourselves.
	return ctx.modelRegistry.getApiKeyForProvider(provider);
}

async function claudeToken(): Promise<string | undefined> {
	try {
		const path = join(process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude"), ".credentials.json");
		const oauth = object(object(JSON.parse(await readFile(path, "utf8"))).claudeAiOauth);
		const expires = number(oauth.expiresAt);
		if (expires !== undefined && expires <= Date.now()) return undefined;
		return typeof oauth.accessToken === "string" && oauth.accessToken ? oauth.accessToken : undefined;
	} catch {
		return undefined;
	}
}

async function requestHeaders(ctx: ExtensionContext, provider: Provider): Promise<Record<string, string> | undefined> {
	const token = provider === "openai"
		? await piToken(ctx, "openai-codex")
		: ctx.model?.provider === "anthropic"
			? await piToken(ctx, "anthropic") ?? await claudeToken()
			: await claudeToken() ?? await piToken(ctx, "anthropic");
	if (!token) return undefined;
	const headers: Record<string, string> = { Authorization: `Bearer ${token}`, Accept: "application/json" };
	if (provider === "openai") {
		const id = accountId(token);
		if (id) headers["ChatGPT-Account-Id"] = id;
	} else {
		headers["anthropic-beta"] = "oauth-2025-04-20";
	}
	return headers;
}

export default async function (pi: ExtensionAPI, readGit = queryGitStatus) {
	const { mixColors, parseColor, truncateToWidth, visibleWidth } = await import("@earendil-works/pi-tui");
	const base = parseColor("#24273a");
	const peach = parseColor("#f5a97f");
	// Macchiato hues distinguish providers and their short/weekly windows.
	const quotaColors = {
		openai: [parseColor("#91d7e3"), parseColor("#8aadf4")],
		anthropic: [peach, mixColors(peach, parseColor("#24273a"), 0.2)],
	};
	const states: Record<Provider, State> = {
		openai: { quotas: [], nextAt: 0, retryAt: 0 },
		anthropic: { quotas: [], nextAt: 0, retryAt: 0 },
	};
	let ctx: ExtensionContext | undefined;
	let timer: ReturnType<typeof setInterval> | undefined;
	let redraw: (() => void) | undefined;
	let stopped = true;
	const controllers = new Set<AbortController>();
	const git: { cwd?: string; status?: GitStatus; error?: boolean; nextAt: number; pending?: Promise<void>; controller?: AbortController } = { nextAt: 0 };

	function refreshGit(force = false): Promise<void> {
		if (!ctx || stopped) return Promise.resolve();
		const cwd = ctx.cwd;
		const changed = git.cwd !== cwd;
		if (changed) {
			git.cwd = cwd;
			git.status = undefined;
			git.error = false;
			git.nextAt = 0;
			git.controller?.abort();
		}
		if (git.pending) return changed ? git.pending.then(() => refreshGit(true)) : git.pending;
		if (!force && Date.now() < git.nextAt) return Promise.resolve();
		git.nextAt = Date.now() + 2000;
		const controller = new AbortController();
		git.controller = controller;
		controllers.add(controller);
		git.pending = (async () => {
			try {
				const status = await Promise.resolve().then(() => readGit(cwd, controller.signal));
				if (!stopped && git.cwd === cwd) { git.status = status; git.error = false; }
			} catch {
				if (!stopped && git.cwd === cwd) { git.status = undefined; git.error = true; }
			} finally {
				controllers.delete(controller);
				git.pending = undefined;
				redraw?.();
			}
		})();
		return git.pending;
	}

	function overlayBar(context: ExtensionContext, percent: number | undefined, label: string, color: typeof base, width = WIDTH): string {
		const { filled, remaining } = overlayParts(percent, label, width);
		const theme = context.ui.theme;
		return (filled ? theme.style(filled, { fg: base, bg: color }) : "") +
			(remaining ? theme.style(remaining, { fg: color, bg: mixColors(color, base, 0.75) }) : "");
	}

	function installFooter(context: ExtensionContext): void {
		context.ui.setStatus("usage-bars-context", undefined);
		context.ui.setStatus("usage-bars-limit", undefined);
		context.ui.setFooter((tui, _theme, footerData) => {
			redraw = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(() => { void refreshGit(true); redraw?.(); });
			let leaf: string | null | undefined;
			let stats = "";
			return {
				dispose() { unsubscribe(); redraw = undefined; },
				invalidate() {},
				render(width: number): string[] {
					const current = ctx ?? context;
					const theme = current.ui.theme;
					const now = Date.now();
					const gitStatus = git.cwd === current.cwd ? git.status : undefined;
					const branch = gitStatus?.branch ?? footerData.getGitBranch();
					const nextLeaf = current.sessionManager.getLeafId();
					if (nextLeaf !== leaf) {
						leaf = nextLeaf;
						let input = 0, output = 0;
						for (const entry of current.sessionManager.getBranch()) {
							if (entry.type !== "message" || entry.message.role !== "assistant") continue;
							input += entry.message.usage.input + entry.message.usage.cacheRead + entry.message.usage.cacheWrite;
							output += entry.message.usage.output;
						}
						const count = (tokens: number) => tokens < 1000 ? `${tokens}` : `${Number((tokens / 1000).toFixed(1))}k`;
						stats = `${count(output)}/${count(input)}`;
					}
					if (width <= 0) return [""];
					const percent = current.getContextUsage()?.percent ?? undefined;
					const percentText = percent === undefined ? "?" : `${Math.round(percent)}%`;
					const contextColor = theme.colors[percent === undefined ? "dim" : percent < 60 ? "success" : percent < 85 ? "warning" : "error"];
					const model = theme.fg("text", current.model?.id ?? "no model");
					const modelEffort = model + theme.fg("muted", ` ◈ ${pi.getThinkingLevel()}`);
					const info = " " + theme.fg("muted", stats) + " " + modelEffort;
					const fullLeft = overlayBar(current, percent, percentText, contextColor) + info;
					const compactLeft = overlayBar(current, percent, percentText, contextColor, 4) + info;
					if (width < 12) return [truncateToWidth(compactLeft, width)];
					const providerText = (provider: Provider, mode: number): string => {
						const state = states[provider];
						const barWidth = mode === 0 ? WIDTH : mode === 1 ? 6 : mode === 2 ? 4 : 0;
						const windows = state.quotas.length ? state.quotas : [{ percent: undefined }, { percent: undefined }];
						const parts = windows.map((window, index) => {
							const reset = "resetAt" in window ? window.resetAt : undefined;
							const used = reset !== undefined && reset <= now ? undefined : window.percent;
							const color = quotaColors[provider][index % 2];
							let time = reset ? formatReset(reset, now) : "?";
							if (barWidth && time.length > barWidth) time = time.match(/^\d+[dhm]/)?.[0] ?? time;
							const text = used === undefined ? "?" : `${Math.floor(used)}%`;
							return (barWidth ? overlayBar(current, used, time, color, barWidth) + " " : "") +
								theme.style(barWidth ? text.padStart(4) : text, { fg: color, dim: used === undefined });
						});
						const stale = state.error || (state.quotas.length && now > state.nextAt + POLL_MS ? "stale" : "");
						return parts.join(" ") + (stale ? theme.fg("warning", mode < 3 ? ` [${stale}]` : " !") : "");
					};
					const gitInfo = gitStatus ? gitIndicators(gitStatus).map(({ color, text }) => theme.fg(color, ` ${text}`)).join("")
						: branch ? theme.fg("muted", git.error ? " [git?]" : " …") : "";
					const branchInfo = branch ? theme.fg("success", `  ${branch}`) + gitInfo : "";
					// Compact quota bars before dropping the branch and git indicators.
					let quotas = "", leftBase = fullLeft;
					for (let mode = 0; mode <= 3; mode++) {
						leftBase = mode < 3 ? fullLeft : compactLeft;
						quotas = providerText("openai", mode) + theme.fg("dim", " │ ") + providerText("anthropic", mode);
						if (visibleWidth(leftBase + branchInfo) + 2 + visibleWidth(quotas) <= width) break;
					}
					quotas = truncateToWidth(quotas, Math.max(0, width - Math.min(8, visibleWidth(leftBase)) - 2));
					const leftWidth = Math.max(0, width - visibleWidth(quotas) - 2);
					const statuses = [...footerData.getExtensionStatuses().values()].join(" ");
					const details = statuses ? theme.fg("dim", `  ${statuses}`) : "";
					const location = theme.fg("text", `  ${current.cwd}`) + branchInfo;
					const candidates = [leftBase + location + details, leftBase + location, leftBase + branchInfo, leftBase + details, leftBase];
					const left = truncateToWidth(candidates.find((text) => visibleWidth(text) <= leftWidth) ?? leftBase, leftWidth);
					return [left + " ".repeat(Math.max(0, width - visibleWidth(left) - visibleWidth(quotas))) + quotas];
				},
			};
		});
	}

	function refresh(provider: Provider, force = false): Promise<void> {
		const state = states[provider];
		if (state.pending) return state.pending;
		if (!ctx || stopped || Date.now() < state.retryAt || (!force && Date.now() < state.nextAt)) return Promise.resolve();
		const context = ctx;
		state.nextAt = Date.now() + POLL_MS;
		const controller = new AbortController();
		controllers.add(controller);
		const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
		state.pending = (async () => {
			try {
				const headers = await requestHeaders(context, provider);
				if (stopped || controller.signal.aborted) return;
				if (!headers) { state.quotas = []; state.error = "login"; return; }
				const response = await fetch(ENDPOINTS[provider], {
					headers, signal: controller.signal, redirect: "error",
				});
				if (!response.ok) {
					await response.body?.cancel();
					state.error = response.status === 401 || response.status === 403 ? "auth" : `HTTP ${response.status}`;
					if (response.status === 429) state.retryAt = retryAt(response.headers.get("retry-after"));
					return;
				}
				const quotas = parseQuotas(provider, await response.json());
				if (!quotas.length) { state.error = "no quota data"; return; }
				state.quotas = quotas;
				state.error = undefined;
			} catch {
				// Never display exception messages, headers, tokens or response bodies.
				if (!stopped) state.error = controller.signal.aborted ? "timeout" : "unavailable";
			} finally {
				clearTimeout(timeout);
				controllers.delete(controller);
				state.pending = undefined;
				redraw?.();
			}
		})();
		return state.pending;
	}

	async function refreshAll(force = false): Promise<void> {
		await Promise.all([refresh("openai", force), refresh("anthropic", force)]);
	}

	pi.on("session_start", (_event, context) => {
		if (context.mode !== "tui") return;
		ctx = context;
		stopped = false;
		installFooter(context);
		// Install again after other session_start handlers (e.g. Catppuccin's optional footer).
		void refreshAll().then(() => { if (!stopped && ctx) installFooter(ctx); });
		void refreshGit(true);
		if (timer) clearInterval(timer);
		timer = setInterval(() => { void refreshAll(); void refreshGit(); redraw?.(); }, 30_000);
		timer.unref();
	});

	const update = (_event: unknown, context: ExtensionContext): void => {
		if (context.mode !== "tui") return;
		const changedProvider = ctx?.model?.provider !== context.model?.provider;
		ctx = context;
		void refreshAll(changedProvider);
		void refreshGit(object(_event).type === "agent_settled");
		redraw?.();
	};
	pi.on("model_select", update);
	pi.on("thinking_level_select", update);
	pi.on("session_tree", update);
	pi.on("session_compact", update);
	pi.on("agent_settled", update);
	pi.on("tool_execution_end", update);

	pi.registerCommand("usage-bars", {
		description: "Refresh subscription quotas (OpenAI and Anthropic); respect server retry delays.",
		handler: async (_args, context) => {
			if (context.mode !== "tui") return;
			ctx = context;
			await Promise.all([refreshAll(true), refreshGit(true)]);
			if (stopped) return;
			installFooter(context);
			const errors = Object.entries(states).filter(([, state]) => state.error).map(([name, state]) => `${name}: ${state.error}`);
			context.ui.notify(errors.length ? errors.join("; ") : "Subscription quotas refreshed", errors.length ? "warning" : "info");
		},
	});

	pi.on("session_shutdown", () => {
		stopped = true;
		if (timer) clearInterval(timer);
		timer = undefined;
		for (const controller of controllers) controller.abort();
		ctx?.ui.setFooter(undefined);
		ctx = undefined;
	});
}
