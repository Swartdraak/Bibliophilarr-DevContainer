import { readFile } from 'node:fs/promises';
import { URL } from 'node:url';
import type { CommandResult } from './types.js';
import { redactText } from './redaction.js';

export interface ApiClientOptions {
  baseUrl: string;
  token?: string;
  timeoutMs?: number;
  caFile?: string;
}

export interface CoderApiState {
  reachable: boolean;
  version: string | null;
  organization: string | null;
  notes: string[];
}

export async function coderApiRequest(path: string, options: ApiClientOptions, init: RequestInit = {}): Promise<Response> {
  const url = new URL(path, options.baseUrl).toString();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs ?? 10_000);
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (options.token) {
    headers.set('Authorization', `Bearer ${options.token}`);
  }
  if (options.caFile) {
    await readFile(options.caFile, 'utf8').catch(() => undefined);
  }
  try {
    return await fetch(url, { ...init, headers, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

export async function inspectCoderApi(options: ApiClientOptions): Promise<CoderApiState> {
  const notes: string[] = [];
  try {
    const response = await coderApiRequest('/api/v2/buildinfo', options);
    if (!response.ok) {
      notes.push(`buildinfo HTTP ${response.status}`);
      return { reachable: false, version: null, organization: null, notes };
    }
    const body = await response.json() as { version?: string; organization?: string };
    return {
      reachable: true,
      version: body.version ?? null,
      organization: body.organization ?? null,
      notes,
    };
  } catch (error) {
    notes.push(redactText(String(error)));
    return { reachable: false, version: null, organization: null, notes };
  }
}

export function summarizeCommand(result: CommandResult): string {
  return redactText(`${result.command} ${result.args.join(' ')} -> ${result.exitCode} (${result.durationMs}ms)`);
}