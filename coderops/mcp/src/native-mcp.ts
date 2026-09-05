import { runCommand } from './command-runner.js';

export interface NativeMcpCapability {
  available: boolean;
  local_stdio: boolean;
  remote_http: boolean;
  reason: string | null;
}

export async function inspectNativeCoderMcp(): Promise<NativeMcpCapability> {
  const result = await runCommand('coder', ['exp', 'mcp', 'server', '--help'], { timeoutMs: 5000 });
  return {
    available: result.exitCode === 0,
    local_stdio: result.exitCode === 0,
    remote_http: false,
    reason: result.exitCode === 0 ? null : (result.stderr || result.stdout || 'coder exp mcp server unavailable'),
  };
}