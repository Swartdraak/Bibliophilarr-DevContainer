import { runCommand } from './command-runner.js';

export interface CoderCliState {
  installed: boolean;
  version: string;
  help: string;
  expMcpAvailable: boolean;
  remoteMcpAvailable: boolean;
  templatesHelp: string;
  workspacesHelp: string;
  provisionerHelp: string;
}

export async function inspectCoderCli(): Promise<CoderCliState> {
  const version = await runCommand('coder', ['version'], { timeoutMs: 5000 });
  const help = await runCommand('coder', ['--help'], { timeoutMs: 5000 });
  const exp = await runCommand('coder', ['exp', '--help'], { timeoutMs: 5000 });
  const mcp = await runCommand('coder', ['exp', 'mcp', '--help'], { timeoutMs: 5000 });
  const server = await runCommand('coder', ['exp', 'mcp', 'server', '--help'], { timeoutMs: 5000 });
  const templatesHelp = await runCommand('coder', ['templates', '--help'], { timeoutMs: 5000 });
  const workspacesHelp = await runCommand('coder', ['workspaces', '--help'], { timeoutMs: 5000 });
  const provisionerHelp = await runCommand('coder', ['provisionerd', '--help'], { timeoutMs: 5000 });
  return {
    installed: version.exitCode === 0,
    version: version.stdout.trim() || version.stderr.trim() || 'unknown',
    help: help.stdout,
    expMcpAvailable: exp.exitCode === 0 && mcp.exitCode === 0 && server.exitCode === 0,
    remoteMcpAvailable: false,
    templatesHelp: templatesHelp.stdout,
    workspacesHelp: workspacesHelp.stdout,
    provisionerHelp: provisionerHelp.stdout,
  };
}

export async function whoAmI(): Promise<{ authenticated: boolean; output: string }> {
  const result = await runCommand('coder', ['whoami', '-o', 'json'], { timeoutMs: 5000 });
  return { authenticated: result.exitCode === 0, output: result.stdout || result.stderr };
}

export async function listTemplates(): Promise<string> {
  const result = await runCommand('coder', ['templates', 'list'], { timeoutMs: 10000 });
  return result.stdout || result.stderr;
}