import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "thinking-brain";
const LABELS: Record<string, string> = { off: "off", minimal: "min", low: "low", medium: "med", high: "high", xhigh: "xhigh", max: "max" };

export function thinkingStatus(level: string): string {
	return `🧠 ${LABELS[level] ?? level}`;
}

export default function (pi: ExtensionAPI): void {
	const update = (_event: unknown, ctx: ExtensionContext): void => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setStatus(STATUS_KEY, thinkingStatus(pi.getThinkingLevel()));
	};
	pi.on("session_start", update);
	pi.on("model_select", update);
	pi.on("thinking_level_select", update);
	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode === "tui") ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
