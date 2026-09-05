import { runCommand } from './command-runner.js';

export interface AiState {
  enabled: boolean;
  provider: string | null;
  baseUrl: string | null;
  model: string | null;
  reachable: boolean;
  notes: string[];
}

export async function inspectAi(): Promise<AiState> {
  const provider = process.env.LOCAL_LLM_PROVIDER ?? process.env.COPILOT_PROVIDER_TYPE ?? null;
  const baseUrl = process.env.LOCAL_LLM_BASE_URL || process.env.COPILOT_PROVIDER_BASE_URL || null;
  const model = process.env.LOCAL_LLM_MODEL || process.env.COPILOT_MODEL || null;
  const enabled = Boolean(provider && provider !== 'none');
  const notes: string[] = [];
  let reachable = false;
  if (baseUrl) {
    try {
      const response = await fetch(new URL('/v1/models', baseUrl), { method: 'GET' });
      reachable = response.ok;
    } catch (error) {
      notes.push(String(error));
    }
  }
  const copilot = await runCommand('copilot', ['--version'], { timeoutMs: 4000 });
  if (copilot.exitCode !== 0) {
    notes.push('copilot CLI not available');
  }
  return { enabled, provider, baseUrl, model, reachable, notes };
}