import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

type ModelRecord = {
	id: string;
	name: string;
	reasoning: boolean;
	input: Array<"text" | "image">;
	contextWindow: number;
	maxTokens: number;
};

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const MODELS_FILE = join(AGENT_DIR, "models.json");
const SYNC_SCRIPT = join(AGENT_DIR, "bin", "sync-lmstudio-models");
const LM_STUDIO_HOME = process.env.LM_STUDIO_HOME || process.env.LMSTUDIO_HOME || join(homedir(), ".lmstudio");
const LM_STUDIO_MODEL_CONFIG_DIR = join(LM_STUDIO_HOME, ".internal", "user-concrete-model-default-config");
const DEFAULT_CONTEXT_WINDOW = 128000;
const DEFAULT_MAX_TOKENS = 8192;

const KNOWN_MODEL_HINTS: Record<
	string,
	Pick<ModelRecord, "name" | "input" | "contextWindow" | "maxTokens">
> = {
	"google/gemma-4-e4b": {
		name: "Gemma 4 E4B (LM Studio)",
		input: ["text", "image"],
		contextWindow: 131072,
		maxTokens: 8192,
	},
	"google/gemma-4-12b": {
		name: "Gemma 4 12B (LM Studio)",
		input: ["text"],
		contextWindow: 32768,
		maxTokens: 8192,
	},
};

function isEmbeddingModel(modelId: string): boolean {
	return modelId.toLowerCase().includes("embed");
}

function getModelContextLength(modelId: string): number | undefined {
	const configPath = `${join(LM_STUDIO_MODEL_CONFIG_DIR, ...modelId.split("/"))}.json`;

	if (!existsSync(configPath)) {
		return undefined;
	}

	try {
		const raw = readFileSync(configPath, "utf8");
		const payload = JSON.parse(raw) as {
			load?: {
				fields?: Array<{
					key?: string;
					value?: {
						checked?: boolean;
						value?: number;
					} | number;
				}>;
			};
		};

		const fields = payload?.load?.fields;
		if (!Array.isArray(fields)) {
			return undefined;
		}

		const contextField = fields.find((field) => field?.key === "llm.load.contextLength");
		if (!contextField) {
			return undefined;
		}

		const rawValue = contextField.value;
		if (typeof rawValue === "number") {
			return rawValue;
		}

		if (rawValue && typeof rawValue === "object" && typeof rawValue.value === "number") {
			return rawValue.value;
		}
	} catch {
		return undefined;
	}

	return undefined;
}

function parseModelHint(modelId: string) {
	const hint = KNOWN_MODEL_HINTS[modelId];
	const contextWindowFromConfig = getModelContextLength(modelId);
	return {
		reasoning: false,
		input: hint?.input ?? ["text"],
		contextWindow: contextWindowFromConfig ?? hint?.contextWindow ?? DEFAULT_CONTEXT_WINDOW,
		maxTokens: hint?.maxTokens ?? DEFAULT_MAX_TOKENS,
		name: hint?.name ?? modelId,
	};
}

function loadProviderDefaults() {
	try {
		const raw = readFileSync(MODELS_FILE, "utf8");
		const parsed = JSON.parse(raw) as { providers?: Record<string, { baseUrl?: string; api?: string; apiKey?: string; compat?: Record<string, unknown> }> };
		const lmstudio = parsed.providers?.lmstudio;
		return {
			baseUrl: lmstudio?.baseUrl ?? "http://localhost:1234/v1",
			api: lmstudio?.api ?? "openai-completions",
			apiKey: lmstudio?.apiKey ?? "lmstudio",
			compat: lmstudio?.compat,
		};
	} catch {
		return {
			baseUrl: "http://localhost:1234/v1",
			api: "openai-completions",
			apiKey: "lmstudio",
			compat: undefined,
		};
	}
}

function hasTokens(stdout: string, stderr: string): boolean {
	return Boolean((stdout && stdout.trim()) || (stderr && stderr.trim()));
}

async function syncLmstudioInSession(pi: ExtensionAPI): Promise<ModelRecord[]> {
	const { baseUrl, api, apiKey, compat } = loadProviderDefaults();
	const response = await fetch(`${baseUrl}/models`);
	if (!response.ok) {
		raiseError(`LM Studio returned ${response.status} ${response.statusText}`);
	}

	const payload = (await response.json()) as { data?: Array<{ id?: string }> };
	const remoteModels = Array.isArray(payload.data) ? payload.data : [];

	const models: ModelRecord[] = [];
	for (const model of remoteModels) {
		const id = model?.id;
		if (typeof id !== "string" || id.length === 0) continue;
		if (isEmbeddingModel(id)) continue;
		const hint = parseModelHint(id);
		models.push({
			id,
			name: hint.name,
			reasoning: hint.reasoning,
			input: hint.input,
			contextWindow: hint.contextWindow,
			maxTokens: hint.maxTokens,
		});
	}

	if (models.length === 0) {
		raiseError("No LM Studio models were discovered");
	}

	pi.registerProvider("lmstudio", {
		baseUrl,
		api,
		apiKey,
		compat: compat ?? {
			supportsDeveloperRole: false,
			supportsReasoningEffort: false,
			supportsUsageInStreaming: false,
			maxTokensField: "max_tokens",
		},
		models,
	});

	return models;
}

function raiseError(message: string): never {
	throw new Error(message);
}

export default async function syncLmstudioCommand(pi: ExtensionAPI) {
	const run = async (_args: string, ctx: ExtensionCommandContext): Promise<void> => {
		if (existsSync(SYNC_SCRIPT)) {
			const scriptResult = await pi.exec(SYNC_SCRIPT, [], { timeout: 20_000 });
			if (scriptResult.code !== 0 || !hasTokens(scriptResult.stdout, scriptResult.stderr)) {
				const details = (scriptResult.stdout + "\n" + scriptResult.stderr).trim() || "Failed to run sync script.";
				ctx.ui.notify(details, "error");
			} else {
				ctx.ui.notify(scriptResult.stdout.trim(), "info");
			}
		}

		try {
			const models = await syncLmstudioInSession(pi);
			ctx.ui.notify(`Updated Pi registry with ${models.length} lmstudio model(s).`, "info");
			if (!existsSync(SYNC_SCRIPT)) {
				ctx.ui.notify("Also synced the in-session model registry (script not available to persist file).", "warning");
			}
		} catch (error) {
			ctx.ui.notify(`Failed to refresh Pi runtime models: ${String((error as Error)?.message ?? error)}`, "error");
		}
	};

	pi.registerCommand("sync-lmstudio-models", {
		description: "Sync lmstudio model list from running local LM Studio",
		handler: run,
	});
}
