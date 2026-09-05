import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';
import { redactText } from './redaction.js';
import type { CommandResult } from './types.js';

export interface RunCommandOptions {
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
  input?: string;
}

export async function runCommand(command: string, args: string[], options: RunCommandOptions = {}): Promise<CommandResult> {
  const startedAt = Date.now();
  const timeoutMs = options.timeoutMs ?? 30_000;
  return await new Promise<CommandResult>((resolve) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: 'pipe',
      shell: false,
    });
    let stdout = '';
    let stderr = '';
    let timedOut = false;
    const timer = timeoutMs > 0 ? setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
      void delay(1500).then(() => child.kill('SIGKILL')).catch(() => undefined);
    }, timeoutMs) : undefined;
    child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
    if (options.input) {
      child.stdin.end(options.input);
    }
    child.on('error', (error) => {
      if (timer) clearTimeout(timer);
      resolve({
        command,
        args,
        exitCode: 1,
        stdout: redactText(stdout),
        stderr: redactText(`${stderr}\n${String(error.message)}`),
        durationMs: Date.now() - startedAt,
        timedOut,
      });
    });
    child.on('close', (exitCode) => {
      if (timer) clearTimeout(timer);
      resolve({
        command,
        args,
        exitCode: exitCode ?? 0,
        stdout: redactText(stdout),
        stderr: redactText(stderr),
        durationMs: Date.now() - startedAt,
        timedOut,
      });
    });
  });
}