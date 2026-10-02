import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { createRequire, registerHooks } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import usageBars, { accountId, formatReset, gitIndicators, overlayParts, combinedOverlayParts, parseGitStatus, parseQuotas, queryGitStatus, retryAt, type GitStatus } from "../extensions/usage-bars.ts";

// Node's ESM resolver ignores NODE_PATH. Resolve the Pi TUI runtime via CJS.
// Run with Pi's node_modules on NODE_PATH and Node >= 22.19.
const require = createRequire(import.meta.url);
registerHooks({
	resolve(specifier, context, nextResolve) {
		return nextResolve(specifier === "@earendil-works/pi-tui"
			? pathToFileURL(require.resolve(specifier)).href : specifier, context);
	},
});

const now = Math.floor(Date.now() / 1000) * 1000;
const openai = {
	rate_limit: {
		primary_window: { used_percent: 6, reset_at: now / 1000 + 3600, limit_window_seconds: 18000 },
		secondary_window: { used_percent: 80, reset_at: now / 1000 + 86400, limit_window_seconds: 604800 },
	},
};
const anthropic = {
	five_hour: { utilization: 12.5, resets_at: new Date(now + 3600000).toISOString() },
	seven_day: { utilization: 95, resets_at: new Date(now + 86400000).toISOString() },
};

test("OpenAI windows use server duration and Unix reset timestamps", () => {
	assert.deepEqual(parseQuotas("openai", openai), [
		{ label: "5h", percent: 6, resetAt: now + 3600000 },
		{ label: "7d", percent: 80, resetAt: now + 86400000 },
	]);
});

test("Anthropic utilization is already a percentage, not a fraction", () => {
	assert.deepEqual(parseQuotas("anthropic", anthropic), [
		{ label: "5h", percent: 12.5, resetAt: now + 3600000 },
		{ label: "7d", percent: 95, resetAt: now + 86400000 },
	]);
});

test("missing, null, non-numeric and negative quotas are not displayed as zero", () => {
	for (const data of [null, [], {}, { five_hour: null }, { five_hour: { utilization: "10" } }, { five_hour: { utilization: -1 } }]) {
		assert.deepEqual(parseQuotas("anthropic", data), []);
	}
	assert.deepEqual(parseQuotas("anthropic", { five_hour: { utilization: 0, resets_at: null } }), [
		{ label: "5h", percent: 0, resetAt: undefined },
	]);
	assert.equal(parseQuotas("anthropic", { five_hour: { utilization: 150 } })[0].percent, 100);
});

test("account selection reads only the JWT account claim", () => {
	const token = `header.${Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "test-account" } })).toString("base64url")}.signature`;
	assert.equal(accountId(token), "test-account");
	for (const invalid of ["invalid", "a.e30.b", "a.bnVsbA.b"]) assert.equal(accountId(invalid), undefined);
});

test("overlay labels stay inside the bar; low usage has a visible filled cell", () => {
	assert.deepEqual(overlayParts(50, "1h"), { filled: "   1", remaining: "h   " });
	assert.deepEqual(overlayParts(0, "?"), { filled: "", remaining: "   ?    " });
	assert.deepEqual(overlayParts(100, "100%"), { filled: "  100%  ", remaining: "" });
	assert.equal(overlayParts(3, "3h11m").filled.length, 1);
	assert.deepEqual(overlayParts(200, "1h"), overlayParts(100, "1h"));
	assert.deepEqual(overlayParts(-1, "?"), overlayParts(0, "?"));
	assert.deepEqual(overlayParts(undefined, "?"), overlayParts(0, "?"));
	assert.deepEqual(overlayParts(NaN, "?"), overlayParts(0, "?"));
	assert.deepEqual(overlayParts(50, "25%", 4), { filled: "25", remaining: "% " });
	assert.deepEqual(overlayParts(50, "25%", 0), { filled: "", remaining: "" });
});

test("combined bar overlays independent windows on the same full-width scale", () => {
	const parts = combinedOverlayParts(10, 60, "10% 2h (60% 3d)", 20);
	assert.deepEqual(parts.map(({ kind, text }) => [kind, text.length]), [["short", 2], ["weekly", 10], ["empty", 8]]);
	assert.equal(parts.map(({ text }) => text).join(""), overlayParts(0, "10% 2h (60% 3d)", 20).remaining);
	assert.deepEqual(combinedOverlayParts(80, 20, "label", 20).map(({ kind, text }) => [kind, text.length]), [["short", 16], ["empty", 4]]);
	assert.deepEqual(combinedOverlayParts(undefined, 50, "label", 20).map(({ kind, text }) => [kind, text.length]), [["weekly", 10], ["empty", 10]]);
	assert.deepEqual(combinedOverlayParts(undefined, undefined, "?", 20).map(({ kind, text }) => [kind, text.length]), [["empty", 20]]);
	assert.deepEqual(combinedOverlayParts(100, 100, "full", 20).map(({ kind, text }) => [kind, text.length]), [["short", 20]]);
	assert.deepEqual(combinedOverlayParts(10, 50, "label", 0), []);
});

test("reset countdown supports minutes, hours, days and expired windows", () => {
	assert.equal(formatReset(undefined, now), "");
	assert.equal(formatReset(now, now), "now");
	assert.equal(formatReset(now + 1, now), "1m");
	assert.equal(formatReset(now + 3660000, now), "1h1m");
	assert.equal(formatReset(now + 90000000, now), "1d1h");
});

test("429 backoff respects Retry-After and has a five-minute minimum", () => {
	assert.equal(retryAt(null, now), now + 300000);
	assert.equal(retryAt("10", now), now + 300000);
	assert.equal(retryAt("600", now), now + 600000);
	assert.equal(retryAt(new Date(now + 900000).toUTCString(), now), now + 900000);
	assert.equal(retryAt("invalid", now), now + 300000);
});

test("git status separates index/worktree, renames, untracked files, conflicts and divergence", () => {
	const status = parseGitStatus([
		"# branch.oid abc", "# branch.head feature/status", "# branch.upstream origin/feature/status", "# branch.ab +3 -2", "# stash 4",
		"1 M. N... staged.txt", "1 .M N... worktree.txt", "1 MM N... both.txt",
		"2 R. N... renamed.txt", "? original filename\nwith spaces",
		"1 .. S.M. dirty-submodule", "? loose.txt", "? dir/loose.txt", "u UU N... conflicted.txt",
	].join("\0") + "\0");
	assert.deepEqual(status, {
		branch: "feature/status", upstream: true, unborn: false,
		staged: 3, modified: 3, untracked: 2, conflicts: 1, ahead: 3, behind: 2, stash: 4,
	});
	assert.deepEqual(gitIndicators(status).map(({ text }) => text), ["+3", "~3", "?2", "!1", "↑3", "↓2", "≡4"]);
});

test("git status handles clean trees, detached HEAD and branches without upstream", () => {
	const clean = parseGitStatus("# branch.head main\0# branch.upstream origin/main\0# branch.ab +0 -0\0");
	assert.deepEqual(gitIndicators(clean), [{ color: "success", text: "✓" }]);
	const detached = parseGitStatus("# branch.head (detached)\0");
	assert.equal(detached.branch, "detached");
	assert.deepEqual(gitIndicators(detached).map(({ text }) => text), ["✓", "∅"]);
	const unborn = parseGitStatus("# branch.oid (initial)\0# branch.head new-branch\0");
	assert.deepEqual(gitIndicators(unborn).map(({ text }) => text), ["✓", "∅", "new"]);
	assert.throws(() => parseGitStatus(""), /Invalid git status/);
});

test("read-only Git query parses real NUL-delimited output without modifying the repository", async () => {
	const status = await queryGitStatus(join(import.meta.dirname, "../../.."), new AbortController().signal);
	assert.ok(status.branch);
	for (const key of ["staged", "modified", "untracked", "conflicts", "ahead", "behind", "stash"] as const) {
		assert.ok(Number.isInteger(status[key]) && status[key] >= 0);
	}
});

const sampleGit: GitStatus = {
	branch: "main", upstream: true, unborn: false,
	staged: 2, modified: 3, untracked: 1, conflicts: 0, ahead: 2, behind: 1, stash: 4,
};
type Handler = (event: unknown, context: ExtensionContext) => void | Promise<void>;
async function harness(mode = "tui", colors = false, gitReader?: (cwd: string, signal: AbortSignal) => Promise<GitStatus>, statusOnly = false) {
	const { colorToHex, parseColor, styleText } = await import("@earendil-works/pi-tui");
	const styled: Array<{ text: string; color: string; background?: string }> = [];
	const foreground: Array<{ color: string; text: string }> = [];
	let thinkingLevel = "medium";
	let gitResult = { ...sampleGit };
	let gitReads = 0;
	let footerCalls = 0;
	const statuses = new Map<string, string | undefined>();
	const handlers = new Map<string, Handler>();
	let command: Handler | undefined;
	let render: ((width: number) => string[]) | undefined;
	const notifications: string[] = [];
	const context = {
		mode, hasUI: mode === "tui", cwd: "/test/project", model: { id: "test-model", provider: "anthropic" },
		modelRegistry: {
			getAll: () => [{ provider: "openai-codex" }, { provider: "anthropic" }],
			isUsingOAuth: () => true,
			getApiKeyForProvider: async () => "test-oauth-token",
		},
		getContextUsage: () => ({ percent: 25, tokens: 50000 }),
		sessionManager: {
			getLeafId: () => "leaf",
			getBranch: () => [{ type: "message", message: {
				role: "assistant", usage: { input: 3000, cacheRead: 2000, cacheWrite: 1000, output: 1500 },
			} }],
		},
		ui: {
			theme: {
				colors: { success: parseColor("#a6da95"), warning: parseColor("#eed49f"), error: parseColor("#ed8796"), dim: parseColor("#8087a2") },
				fg: (color: string, text: string) => {
					foreground.push({ color, text });
					return colors ? `\x1b[32m${text}\x1b[0m` : text;
				},
				style: (text: string, options: Parameters<typeof styleText>[1]) => {
					styled.push({ text, color: options.fg ? colorToHex(options.fg) : "", background: options.bg ? colorToHex(options.bg) : undefined });
					return colors ? styleText(text, options, "truecolor") : text;
				},
			},
			setStatus: (key: string, value?: string) => statuses.set(key, value),
			notify: (text: string) => notifications.push(text),
			setFooter(factory: ((...args: unknown[]) => { render: (width: number) => string[]; dispose(): void }) | undefined) {
				footerCalls++;
				render = factory?.({ requestRender() {} }, {}, {
					onBranchChange: () => () => {}, getGitBranch: () => "main",
					getExtensionStatuses: () => new Map([["other-extension", "other status"]]),
				}).render;
			},
		},
	} as unknown as ExtensionContext;
	await usageBars({
		getThinkingLevel: () => thinkingLevel,
		on: (event: string, handler: Handler) => handlers.set(event, handler),
		registerCommand: (_name: string, definition: { handler: Handler }) => { command = definition.handler; },
	} as unknown as ExtensionAPI, gitReader ?? (async () => { gitReads++; return { ...gitResult }; }), { statusOnly });
	return {
		start: () => handlers.get("session_start")!({}, context),
		stop: () => handlers.get("session_shutdown")!({}, context),
		refresh: () => command!("", context),
		lines: (width: number) => render!(width),
		thinking: (level: string) => {
			thinkingLevel = level;
			return handlers.get("thinking_level_select")!({}, context);
		},
		git: (result: GitStatus) => { gitResult = result; },
		settled: async () => {
			await handlers.get("agent_settled")!({ type: "agent_settled" }, context);
			await new Promise<void>((resolve) => setImmediate(resolve));
		},
		gitReads: () => gitReads,
		footerCalls: () => footerCalls,
		statuses,
		notifications, styled, foreground,
	};
}

test("one row shows context, output/input tokens, model with effort icon, path and branch; no cost", async () => {
	const original = globalThis.fetch;
	let requests = 0;
	globalThis.fetch = async (url, options) => {
		requests++;
		assert.equal(options?.redirect, "error");
		assert.ok(options?.signal);
		return Response.json(String(url).includes("anthropic") ? anthropic : openai);
	};
	const ui = await harness("tui", true);
	try {
		await ui.start();
		await ui.refresh();
		assert.equal(requests, 2, "refresh coalesces in-flight requests");
		for (const width of [1, 10, 20, 40, 60, 80, 120, 240]) {
			const lines = ui.lines(width).map(stripVTControlCharacters);
			assert.equal(lines.length, 1, "footer never wraps onto another row");
			assert.ok([...lines[0]].length <= width);
			assert.doesNotMatch(lines[0], /OpenAI|Anthropic|OAI|ANT|5h|7d|\bctx\b|\$/);
			if (width >= 60) {
				assert.equal([...lines[0]].length, width, "quotas end at the right edge");
				assert.match(lines[0], /^ *25% +1\.5k\/6k +test-model ◈ medium.*6%.*80%.*│.*12%.*95%$/);
			}
			if (width >= 80) assert.match(lines[0], / main \+2 ~3 \?1 ↑2 ↓1 ≡4/);
		}
		const wide = stripVTControlCharacters(ui.lines(240)[0]);
		assert.match(wide, /other status/);
		assert.match(wide, /^ *25% +1\.5k\/6k +test-model ◈ medium +\/test\/project  main/);
		assert.doesNotMatch(wide, /\(main\)/);
		assert.match(wide, / main \+2 ~3 \?1 ↑2 ↓1 ≡4/);
		assert.ok(ui.foreground.some(({ color, text }) => color === "success" && text === " +2"));
		assert.ok(ui.foreground.some(({ color, text }) => color === "warning" && text === " ~3"));
		assert.match(wide, /test-model.* {2,}1h +6%/);
		assert.ok(ui.foreground.some(({ color, text }) => color === "text" && text === "test-model"));
		assert.ok(ui.foreground.some(({ color, text }) => color === "text" && text.includes("/test/project")));
		assert.ok(ui.foreground.some(({ color, text }) => color === "success" && text === "  main"));
		assert.ok(ui.foreground.some(({ color, text }) => color === "muted" && text === " ◈ medium"));
		assert.doesNotMatch(wide, /[█░↻]/);
		assert.ok(ui.styled.some(({ background, color }) => background === "#91d7e3" && color === "#24273a"), "filled quota inverts its foreground/background");
		await ui.thinking("high");
		assert.match(stripVTControlCharacters(ui.lines(80)[0]), /^ *25% +1\.5k\/6k +test-model ◈ high /);
		assert.ok(ui.styled.some(({ background, color }) => background !== undefined && color === "#a6da95"), "context percentage remains inside a colored track");
		assert.equal(requests, 2, "effort change does not refetch fresh quotas");
		assert.deepEqual(ui.lines(0), [""]);
		assert.ok(ui.styled.some(({ text, color }) => text.includes("6%") && color === "#91d7e3"));
		assert.ok(ui.styled.some(({ text, color }) => text.includes("80%") && color === "#8aadf4"));
		assert.ok(ui.styled.some(({ text, color }) => text.includes("12%") && color === "#f5a97f"));
		const weeklyOrange = ui.styled.find(({ text }) => text.includes("95%"))!.color;
		assert.notEqual(weeklyOrange, "#f5a97f");
		const [red, green, blue] = weeklyOrange.slice(1).match(/../g)!.map((value) => parseInt(value, 16));
		assert.ok(red > green && green > blue, "weekly Anthropic hue is also orange");
	} finally {
		await ui.stop();
		globalThis.fetch = original;
	}
});

test("git refreshes after an agent run and never reports a failed query as clean", async () => {
	const original = globalThis.fetch;
	globalThis.fetch = async (url) => Response.json(String(url).includes("anthropic") ? anthropic : openai);
	const ui = await harness();
	try {
		await ui.start();
		await ui.refresh();
		const previous = ui.gitReads();
		ui.git({ ...sampleGit, staged: 0, modified: 0, untracked: 0, ahead: 0, behind: 0, stash: 0 });
		await ui.settled();
		assert.equal(ui.gitReads(), previous + 1);
		assert.match(stripVTControlCharacters(ui.lines(240)[0]), / main ✓/);
	} finally { await ui.stop(); }
	const failed = await harness("tui", false, async () => { throw new Error("private diagnostic must not appear in UI"); });
	try {
		await failed.start();
		await failed.refresh();
		assert.match(failed.lines(240)[0], / main \[git\?\]/);
		assert.doesNotMatch(failed.lines(240)[0], /✓|private diagnostic/);
	} finally { await failed.stop(); globalThis.fetch = original; }
});

test("git queries start only with a session, coalesce and abort at shutdown", async () => {
	const original = globalThis.fetch;
	globalThis.fetch = async (url) => Response.json(String(url).includes("anthropic") ? anthropic : openai);
	let reads = 0;
	let active: AbortSignal | undefined;
	const ui = await harness("tui", false, async (_cwd, signal) => {
		reads++;
		active = signal;
		return new Promise<GitStatus>((_resolve, reject) => {
			signal.addEventListener("abort", () => reject(new Error("aborted")), { once: true });
		});
	});
	try {
		assert.equal(reads, 0);
		await ui.start();
		const refresh = ui.refresh();
		await new Promise<void>((resolve) => setImmediate(resolve));
		assert.equal(reads, 1);
		await ui.stop();
		await refresh;
		assert.equal(active?.aborted, true);
	} finally {
		await ui.stop();
		globalThis.fetch = original;
	}
});

test("429 errors are visible and manual refresh cannot bypass server backoff", async () => {
	const original = globalThis.fetch;
	let openaiRequests = 0;
	globalThis.fetch = async (url) => {
		if (String(url).includes("anthropic")) return Response.json(anthropic);
		openaiRequests++;
		return new Response(null, { status: 429, headers: { "retry-after": "600" } });
	};
	const ui = await harness();
	try {
		await ui.start();
		await ui.refresh();
		await ui.refresh();
		assert.equal(openaiRequests, 1);
		assert.match(ui.lines(120).join("\n"), /HTTP 429/);
		assert.match(ui.notifications.at(-1)!, /openai: HTTP 429/);
	} finally {
		await ui.stop();
		globalThis.fetch = original;
	}
});

test("non-interactive sessions do not fetch quotas or install a footer", async () => {
	const original = globalThis.fetch;
	globalThis.fetch = async () => { throw new Error("must not fetch"); };
	const ui = await harness("print");
	try {
		await ui.start();
		await ui.refresh();
		assert.deepEqual(ui.notifications, []);
		assert.equal(ui.gitReads(), 0);
	} finally {
		await ui.stop();
		globalThis.fetch = original;
	}
});

test("missing OAuth never uses API keys and does not display fabricated percentages", async () => {
	// Isolate the CLI credential fallback: tests must never read real credentials.
	const directory = await mkdtemp(join(tmpdir(), "pi-quota-test-"));
	const previous = process.env.CLAUDE_CONFIG_DIR;
	process.env.CLAUDE_CONFIG_DIR = directory;
	const handlers = new Map<string, Handler>();
	let command: Handler | undefined;
	const statuses: string[] = [];
	const context = {
		mode: "tui", model: { provider: "anthropic" },
		modelRegistry: {
			getAll: () => [{ provider: "anthropic" }], isUsingOAuth: () => false,
			getApiKeyForProvider: () => { throw new Error("must not resolve API keys"); },
		},
		ui: { setStatus() {}, setFooter() {}, notify: (text: string) => statuses.push(text) },
	} as unknown as ExtensionContext;
	await usageBars({
		on: (name: string, handler: Handler) => handlers.set(name, handler),
		registerCommand: (_name: string, definition: { handler: Handler }) => { command = definition.handler; },
	} as unknown as ExtensionAPI, async () => ({ ...sampleGit }));
	try {
		await handlers.get("session_start")!({}, context);
		await command!("", context);
		assert.match(statuses[0], /openai: login; anthropic: login/);
	} finally {
		await handlers.get("session_shutdown")!({}, context);
		if (previous === undefined) delete process.env.CLAUDE_CONFIG_DIR;
		else process.env.CLAUDE_CONFIG_DIR = previous;
		await rm(directory, { recursive: true });
	}
});

test("Powerline mode publishes colored quotas, without owning the footer or polling Git", async () => {
	const original = globalThis.fetch;
	let requests = 0;
	globalThis.fetch = async (url) => {
		requests++;
		return Response.json(String(url).includes("anthropic") ? anthropic : openai);
	};
	const ui = await harness("tui", true, undefined, true);
	try {
		assert.equal(requests, 0, "loading the extension does not request quotas");
		await ui.start();
		await ui.refresh();
		assert.equal(requests, 2, "in-flight quota refreshes coalesce");
		const openaiStatus = ui.statuses.get("usage-openai")!;
		const anthropicStatus = ui.statuses.get("usage-anthropic")!;
		assert.match(openaiStatus, /\x1b\[/, "status retains ANSI coloring");
		assert.match(stripVTControlCharacters(openaiStatus), /6% +1h.*\(80% +1d0h\)/);
		assert.match(stripVTControlCharacters(anthropicStatus), /12% +1h.*\(95% +1d0h\)/);
		for (const status of [openaiStatus, anthropicStatus]) {
			const plain = stripVTControlCharacters(status);
			assert.equal(plain.length, 27, "one shared 27-cell scale");
			assert.match(plain.trim(), /^\d+% \d+[dhm].* \(\d+% \d+[dhm].*\)$/, "one centered label contains both windows");
			assert.ok(Math.abs(plain.length - plain.trimEnd().length - (plain.length - plain.trimStart().length)) <= 1, "the complete label is centered");
		}
		const { colorToHex, mixColors, parseColor } = await import("@earendil-works/pi-tui");
		for (const [bright, shortFill, weeklyFill] of [["#91d7e3", 2, 20], ["#f5a97f", 3, 23]] as const) {
			const dark = colorToHex(mixColors(parseColor(bright), parseColor("#24273a"), 0.3));
			const brightness = (hex: string) => hex.slice(1).match(/../g)!.reduce((sum, part) => sum + parseInt(part, 16), 0);
			assert.ok(brightness(dark) < brightness(bright), "weekly track is darker for each provider");
			assert.ok(ui.styled.some(({ text, color, background }) => background === bright && color === "#24273a" && text.length === shortFill), "short-window fill follows its own percentage");
			assert.ok(ui.styled.some(({ text, color, background }) => background === dark && color === "#24273a" && text.length === weeklyFill), "weekly fill follows its own percentage");
		}
		assert.ok(ui.styled.filter(({ text }) => text.includes("%")).every(({ background }) => background !== undefined), "percentages are rendered inside colored tracks, not outside");
		assert.doesNotMatch(openaiStatus + anthropicStatus, /test-oauth-token|5h|7d|OpenAI|Anthropic/);
		await ui.thinking("high");
		assert.equal(requests, 2);
		assert.equal(ui.gitReads(), 0);
		assert.equal(ui.footerCalls(), 0);
	} finally {
		await ui.stop();
		globalThis.fetch = original;
	}
	assert.equal(ui.statuses.get("usage-openai"), undefined);
	assert.equal(ui.statuses.get("usage-anthropic"), undefined);
	assert.equal(ui.footerCalls(), 0, "shutdown does not clear the Powerline footer");
});

test("Powerline mode exposes rate-limit errors and respects backoff", async () => {
	const original = globalThis.fetch;
	let requests = 0;
	globalThis.fetch = async () => {
		requests++;
		return new Response(null, { status: 429, headers: { "retry-after": "600" } });
	};
	const ui = await harness("tui", false, undefined, true);
	try {
		await ui.start();
		await ui.refresh();
		await ui.refresh();
		assert.equal(requests, 2);
		for (const provider of ["openai", "anthropic"]) {
			const status = ui.statuses.get(`usage-${provider}`)!;
			assert.match(status, /HTTP 429/);
			assert.doesNotMatch(status, /\d+%/);
		}
		assert.equal(ui.gitReads(), 0);
	} finally { await ui.stop(); globalThis.fetch = original; }
});

test("Powerline mode is inactive in non-interactive sessions", async () => {
	const original = globalThis.fetch;
	let requests = 0;
	globalThis.fetch = async () => { requests++; throw new Error("must not fetch"); };
	const ui = await harness("print", false, undefined, true);
	try {
		await ui.start();
		await ui.refresh();
		assert.equal(requests, 0);
		assert.equal(ui.statuses.size, 0);
		assert.equal(ui.gitReads(), 0);
		assert.equal(ui.footerCalls(), 0);
	} finally { await ui.stop(); globalThis.fetch = original; }
});
