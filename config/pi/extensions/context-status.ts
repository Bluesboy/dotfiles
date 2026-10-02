import type { ContextUsage, ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { overlayParts } from "./usage-bars.ts";

export function contextStatus(usage: ContextUsage | undefined, fallbackWindow?: number): { label: string; percent: number | undefined; color: "dim" | "success" | "warning" | "error" } {
	const count = (value: number | null | undefined): string => value === null || value === undefined || !Number.isFinite(value) || value < 0
		? "?" : value >= 1_000_000 ? `${Number((value / 1_000_000).toFixed(1))}m` : value >= 1000 ? `${Number((value / 1000).toFixed(1))}k` : `${Math.round(value)}`;
	const percent = usage?.percent !== null && usage?.percent !== undefined && Number.isFinite(usage.percent) && usage.percent >= 0 ? usage.percent : undefined;
	return {
		label: `${percent === undefined ? "?" : `${Math.round(percent)}%`} ${count(usage?.tokens)}/${count(usage?.contextWindow ?? fallbackWindow)}`,
		percent,
		color: percent === undefined ? "dim" : percent < 60 ? "success" : percent < 85 ? "warning" : "error",
	};
}

export default async function (pi: ExtensionAPI): Promise<void> {
	const { mixColors, parseColor } = await import("@earendil-works/pi-tui");
	const base = parseColor("#24273a");
	const update = (_event: unknown, ctx: ExtensionContext): void => {
		if (ctx.mode !== "tui") return;
		const { label, percent, color } = contextStatus(ctx.getContextUsage(), ctx.model?.contextWindow);
		const hue = ctx.ui.theme.colors[color];
		const { filled, remaining } = overlayParts(percent, label, 27);
		ctx.ui.setStatus("context-bar",
			(filled ? ctx.ui.theme.style(filled, { fg: base, bg: hue }) : "") +
			(remaining ? ctx.ui.theme.style(remaining, { fg: hue, bg: mixColors(hue, base, 0.75) }) : ""));
	};
	pi.on("session_start", update);
	pi.on("model_select", update);
	pi.on("session_tree", update);
	pi.on("session_compact", update);
	pi.on("message_end", update);
	pi.on("agent_settled", update);
	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode === "tui") ctx.ui.setStatus("context-bar", undefined);
	});
}
