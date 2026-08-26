/**
 * usage-bars
 *
 * Renders progress bars in the Pi status line:
 *   ctx  - context window usage from ctx.getContextUsage()
 *   lim  - provider rate-limit usage parsed from response headers
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const WIDTH = 8;
const FILLED = "█";
const EMPTY = "░";

type RateLimit = {
	label: string;
	percent: number;
	resetAt?: number;
};

let rateLimit: RateLimit | undefined;

function level(percent: number): "success" | "warning" | "error" {
	if (percent < 60) return "success";
	if (percent < 85) return "warning";
	return "error";
}

function bar(ctx: ExtensionContext, percent: number): string {
	const theme = ctx.ui.theme;
	const clamped = Math.max(0, Math.min(100, percent));
	const filled = Math.round((clamped / 100) * WIDTH);
	const body = FILLED.repeat(filled) + EMPTY.repeat(WIDTH - filled);
	return theme.fg(level(clamped), body);
}

function formatReset(resetAt: number | undefined): string {
	if (!resetAt) return "";
	const seconds = Math.round((resetAt - Date.now()) / 1000);
	if (seconds <= 0) return "";
	if (seconds < 60) return ` ${seconds}s`;
	if (seconds < 3600) return ` ${Math.round(seconds / 60)}m`;
	return ` ${Math.round(seconds / 3600)}h`;
}

function parseNumber(value: string | undefined): number | undefined {
	if (!value) return undefined;
	const parsed = Number(value.trim().replace("%", ""));
	return Number.isFinite(parsed) ? parsed : undefined;
}

function parseReset(value: string | undefined): number | undefined {
	if (!value) return undefined;
	const seconds = Number(value);
	if (Number.isFinite(seconds)) {
		return seconds > 1e9 ? seconds * 1000 : Date.now() + seconds * 1000;
	}
	const parsed = Date.parse(value);
	return Number.isFinite(parsed) ? parsed : undefined;
}

/** Extract a used-percentage rate limit from normalized provider headers. */
function readRateLimit(headers: Record<string, string>): RateLimit | undefined {
	const lower: Record<string, string> = {};
	for (const [key, value] of Object.entries(headers)) lower[key.toLowerCase()] = value;

	// Anthropic unified subscription limits report a used percentage directly.
	const unified = parseNumber(lower["anthropic-ratelimit-unified-status"]);
	if (unified !== undefined) {
		return {
			label: "plan",
			percent: unified,
			resetAt: parseReset(lower["anthropic-ratelimit-unified-reset"]),
		};
	}

	// Generic limit/remaining pairs (Anthropic, OpenAI, OpenRouter, ...).
	const candidates: Array<[string, string, string, string]> = [
		["tokens", "anthropic-ratelimit-tokens-limit", "anthropic-ratelimit-tokens-remaining", "anthropic-ratelimit-tokens-reset"],
		["tokens", "x-ratelimit-limit-tokens", "x-ratelimit-remaining-tokens", "x-ratelimit-reset-tokens"],
		["req", "x-ratelimit-limit-requests", "x-ratelimit-remaining-requests", "x-ratelimit-reset-requests"],
		["req", "x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-reset"],
	];

	for (const [label, limitKey, remainingKey, resetKey] of candidates) {
		const limit = parseNumber(lower[limitKey]);
		const remaining = parseNumber(lower[remainingKey]);
		if (limit === undefined || remaining === undefined || limit <= 0) continue;
		return {
			label,
			percent: ((limit - remaining) / limit) * 100,
			resetAt: parseReset(lower[resetKey]),
		};
	}

	return undefined;
}

function render(ctx: ExtensionContext): void {
	const theme = ctx.ui.theme;
	const usage = ctx.getContextUsage();

	if (usage && usage.percent !== null) {
		const percent = usage.percent;
		const tokens = usage.tokens ?? 0;
		const text =
			theme.fg("dim", "ctx ") +
			bar(ctx, percent) +
			theme.fg("dim", ` ${Math.round(percent)}% ${Math.round(tokens / 1000)}k`);
		ctx.ui.setStatus("usage-bars-context", text);
	} else {
		ctx.ui.setStatus("usage-bars-context", theme.fg("dim", `ctx ${EMPTY.repeat(WIDTH)}  ?`));
	}

	if (rateLimit) {
		const text =
			theme.fg("dim", `${rateLimit.label} `) +
			bar(ctx, rateLimit.percent) +
			theme.fg("dim", ` ${Math.round(rateLimit.percent)}%${formatReset(rateLimit.resetAt)}`);
		ctx.ui.setStatus("usage-bars-limit", text);
	} else {
		ctx.ui.setStatus("usage-bars-limit", undefined);
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("after_provider_response", (event, ctx) => {
		const parsed = readRateLimit(event.headers ?? {});
		if (parsed) {
			rateLimit = parsed;
			render(ctx);
		}
	});

	for (const event of [
		"session_start",
		"turn_end",
		"message_end",
		"agent_settled",
		"model_select",
		"session_compact",
	] as const) {
		pi.on(event, (_event, ctx) => render(ctx));
	}
}
