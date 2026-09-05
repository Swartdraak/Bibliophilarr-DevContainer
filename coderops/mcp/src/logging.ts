import { appendFile, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { redactValue } from './redaction.js';

export interface LogEntry {
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error';
  message: string;
  fields?: Record<string, unknown>;
}

export function stateDir(): string {
  const base = process.env.XDG_STATE_HOME || `${process.env.HOME ?? '/tmp'}/.local/state`;
  return `${base}/coderops`;
}

export async function writeJsonl(entry: LogEntry): Promise<void> {
  const file = `${stateDir()}/audit.jsonl`;
  await mkdir(dirname(file), { recursive: true });
  const sanitized = redactValue(entry) as LogEntry;
  await appendFile(file, `${JSON.stringify(sanitized)}\n`, 'utf8');
}

export function createLogger(quiet = false) {
  const emit = (level: LogEntry['level'], message: string, fields?: Record<string, unknown>) => {
    if (!quiet) {
      const suffix = fields ? ` ${JSON.stringify(redactValue(fields))}` : '';
      // eslint-disable-next-line no-console
      console.log(`[${level}] ${message}${suffix}`);
    }
  };
  return {
    debug: (message: string, fields?: Record<string, unknown>) => emit('debug', message, fields),
    info: (message: string, fields?: Record<string, unknown>) => emit('info', message, fields),
    warn: (message: string, fields?: Record<string, unknown>) => emit('warn', message, fields),
    error: (message: string, fields?: Record<string, unknown>) => emit('error', message, fields),
  };
}