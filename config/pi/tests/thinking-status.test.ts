import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import thinkingExtension, { thinkingStatus } from "../extensions/thinking-status.ts";

test("brain status formats every effort level", () => {
	for (const [level, label] of Object.entries({ off: "off", minimal: "min", low: "low", medium: "med", high: "high", xhigh: "xhigh", max: "max" })) {
		assert.equal(thinkingStatus(level), `🧠 ${label}`);
	}
	assert.equal(thinkingStatus("future"), "🧠 future");
});

test("status follows startup, model and effort changes; shutdown clears it", () => {
	type Handler = (event: unknown, ctx: ExtensionContext) => void;
	const handlers = new Map<string, Handler>();
	const statuses = new Map<string, string | undefined>();
	let level: ReturnType<ExtensionAPI["getThinkingLevel"]> = "medium";
	thinkingExtension({
		on: (event: string, handler: Handler) => handlers.set(event, handler),
		getThinkingLevel: () => level,
	} as unknown as ExtensionAPI);
	const ctx = {
		mode: "tui",
		ui: { setStatus: (key: string, value?: string) => statuses.set(key, value) },
	} as unknown as ExtensionContext;
	handlers.get("session_start")!({}, ctx);
	assert.equal(statuses.get("thinking-brain"), "🧠 med");
	level = "low";
	handlers.get("model_select")!({}, ctx);
	assert.equal(statuses.get("thinking-brain"), "🧠 low");
	level = "high";
	handlers.get("thinking_level_select")!({}, ctx);
	assert.equal(statuses.get("thinking-brain"), "🧠 high");
	handlers.get("session_shutdown")!({}, ctx);
	assert.equal(statuses.get("thinking-brain"), undefined);
	statuses.clear();
	const nonInteractive = { mode: "print" } as ExtensionContext;
	for (const handler of handlers.values()) handler({}, nonInteractive);
	assert.equal(statuses.size, 0);
});
