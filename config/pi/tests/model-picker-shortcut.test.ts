import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import extension from "../extensions/model-picker-shortcut.ts";

function harness(available = true) {
	let handler!: (ctx: ExtensionContext) => Promise<void>;
	const messages: Array<{ text: string; options: unknown }> = [];
	const warnings: string[] = [];
	extension({
		registerShortcut: (key: string, options: { handler: typeof handler }) => {
			assert.equal(key, "alt+m");
			handler = options.handler;
		},
		getCommands: () => available ? [{ name: "model-picker" }] : [],
		sendUserMessage: (text: string, options: unknown) => messages.push({ text, options }),
	} as unknown as ExtensionAPI);
	return {
		messages, warnings,
		run: (mode = "tui") => handler({ mode, ui: { notify: (text: string) => warnings.push(text) } } as unknown as ExtensionContext),
	};
}

test("Alt+M dispatches /model-picker as an extension command, not a model prompt", async () => {
	const ui = harness();
	await ui.run();
	assert.deepEqual(ui.messages, [{ text: "/model-picker", options: { expandPromptTemplates: true } }]);
	assert.deepEqual(ui.warnings, []);
});

test("missing picker or non-interactive mode cannot submit a model prompt", async () => {
	const missing = harness(false);
	await missing.run();
	assert.deepEqual(missing.messages, []);
	assert.equal(missing.warnings.length, 1);
	const nonInteractive = harness();
	await nonInteractive.run("print");
	assert.deepEqual(nonInteractive.messages, []);
	assert.deepEqual(nonInteractive.warnings, []);
});
