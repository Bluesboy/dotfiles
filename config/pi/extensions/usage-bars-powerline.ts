import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import usageBars from "./usage-bars.ts";

export default async function (pi: ExtensionAPI): Promise<void> {
	await usageBars(pi, undefined, { statusOnly: true });
}
