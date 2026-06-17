import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { homedir } from "node:os";
import { join } from "node:path";

const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const webBin = join(agentDir, "bin", "web");

export default function webTools(pi: ExtensionAPI) {
	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Run a live web search and return timestamped source URLs and snippets. Use for current facts, recent events, external documentation, or any user request to search the web.",
		promptSnippet: "Live web search with timestamped source URLs/snippets",
		promptGuidelines: [
			"Use web_search whenever the user asks to search the web, look up current/recent information, or verify an external fact.",
			"After web_search, use web_fetch on an official or high-quality result before answering factual current-information questions.",
			"Never claim to have searched the web unless web_search or another real web tool succeeded.",
		],
		parameters: Type.Object({
			query: Type.String({ description: "Search query" }),
			numResults: Type.Optional(
				Type.Number({ description: "Number of results, 1-20", minimum: 1, maximum: 20, default: 5 }),
			),
			includeContent: Type.Optional(
				Type.Boolean({ description: "Fetch readable page content for each result", default: false }),
			),
		}),
		async execute(_toolCallId, params, signal) {
			const args = ["search", params.query, "-n", String(Math.min(20, Math.max(1, params.numResults ?? 5)))];
			if (params.includeContent) args.push("--content");
			const result = await pi.exec(webBin, args, { signal, timeout: 60_000 });
			const text = [result.stdout, result.stderr].filter(Boolean).join("\n").trim();
			if (result.code !== 0) {
				throw new Error(text || `web_search failed with exit code ${result.code}`);
			}
			return {
				content: [{ type: "text", text }],
				details: { command: webBin, args, code: result.code },
			};
		},
	});

	pi.registerTool({
		name: "web_fetch",
		label: "Web Fetch",
		description: "Fetch readable markdown content from a URL. Use after web_search to verify and cite source content.",
		promptSnippet: "Fetch readable markdown from a URL",
		promptGuidelines: [
			"Use web_fetch after web_search to verify official/current source content before answering factual questions.",
			"Cite the URL returned by web_fetch or web_search when giving web-derived answers.",
		],
		parameters: Type.Object({
			url: Type.String({ description: "HTTP or HTTPS URL to fetch" }),
		}),
		async execute(_toolCallId, params, signal) {
			const result = await pi.exec(webBin, ["fetch", params.url], { signal, timeout: 60_000 });
			const text = [result.stdout, result.stderr].filter(Boolean).join("\n").trim();
			if (result.code !== 0) {
				throw new Error(text || `web_fetch failed with exit code ${result.code}`);
			}
			return {
				content: [{ type: "text", text }],
				details: { command: webBin, args: ["fetch", params.url], code: result.code },
			};
		},
	});
}
