import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.registerShortcut("alt+m", {
		description: "Open the enhanced model picker",
		handler: async (ctx) => {
			if (ctx.mode !== "tui") return;
			if (!pi.getCommands().some((command) => command.name === "model-picker")) {
				ctx.ui.notify("The /model-picker command is not loaded.", "warning");
				return;
			}
			// Slash-command dispatch requires expansion; never send this as an LLM prompt.
			pi.sendUserMessage("/model-picker", { expandPromptTemplates: true });
		},
	});
}
