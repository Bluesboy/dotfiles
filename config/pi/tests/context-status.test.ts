import assert from "node:assert/strict";
import { test } from "node:test";
import { createRequire, registerHooks } from "node:module";
import { pathToFileURL } from "node:url";
import type { ContextUsage, ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import extension, { contextStatus } from "../extensions/context-status.ts";

const require = createRequire(import.meta.url);
registerHooks({ resolve(specifier, context, next) {
	return next(specifier === "@earendil-works/pi-tui" ? pathToFileURL(require.resolve(specifier)).href : specifier, context);
} });

test("context label formats usage and thresholds", () => {
	assert.deepEqual(contextStatus({ tokens: 84000, contextWindow: 200000, percent: 42 }), { label: "42% 84k/200k", percent: 42, color: "success" });
	for (const [percent, color] of [[0, "success"], [59, "success"], [60, "warning"], [84, "warning"], [85, "error"], [110, "error"]] as const) {
		assert.equal(contextStatus({ tokens: 1000, contextWindow: 200000, percent }).color, color);
	}
	assert.equal(contextStatus({ tokens: 1_000_000, contextWindow: 2_000_000, percent: 50 }).label, "50% 1m/2m");
});

test("unknown context is not displayed as zero", () => {
	assert.deepEqual(contextStatus({ tokens: null, contextWindow: 200000, percent: null }), { label: "? ?/200k", percent: undefined, color: "dim" });
	assert.equal(contextStatus(undefined, 200000).label, "? ?/200k");
	assert.equal(contextStatus(undefined).label, "? ?/?");
	assert.equal(contextStatus({ tokens: NaN, contextWindow: Infinity, percent: NaN }).label, "? ?/?");
});

test("context bar updates after responses and compaction, clears on shutdown, and skips print mode", async () => {
	const { parseColor } = await import("@earendil-works/pi-tui");
	type Handler = (event: unknown, ctx: ExtensionContext) => void;
	const handlers = new Map<string, Handler>();
	await extension({ on: (event: string, handler: Handler) => handlers.set(event, handler) } as unknown as ExtensionAPI);
	let usage: ContextUsage = { tokens: 84000, contextWindow: 200000, percent: 42 };
	let status: string | undefined;
	const styles: string[] = [];
	const ctx = {
		mode: "tui", getContextUsage: () => usage,
		ui: {
			setStatus: (key: string, value?: string) => { assert.equal(key, "context-bar"); status = value; },
			theme: {
				colors: { success: parseColor("#a6da95"), warning: parseColor("#eed49f"), error: parseColor("#ed8796"), dim: parseColor("#8087a2") },
				style: (text: string) => { styles.push(text); return text; },
			},
		},
	} as unknown as ExtensionContext;
	handlers.get("session_start")!({}, ctx);
	assert.equal(status!.length, 27);
	assert.equal(status!.trim(), "42% 84k/200k");
	assert.equal(styles[0].length, 11, "filled cells represent 42% of the track");
	usage = { tokens: 180000, contextWindow: 200000, percent: 90 };
	handlers.get("message_end")!({}, ctx);
	assert.equal(status!.trim(), "90% 180k/200k");
	usage = { tokens: null, contextWindow: 200000, percent: null };
	handlers.get("session_compact")!({}, ctx);
	assert.equal(status!.trim(), "? ?/200k");
	handlers.get("session_shutdown")!({}, ctx);
	assert.equal(status, undefined);
	for (const handler of handlers.values()) handler({}, { mode: "print" } as ExtensionContext);
	assert.equal(status, undefined);
});
