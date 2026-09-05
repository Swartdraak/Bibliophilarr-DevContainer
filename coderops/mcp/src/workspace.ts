import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { runCommand } from './command-runner.js';

export interface WorkspaceState {
  repositoryRoot: string;
  checkedOut: boolean;
  owner: string | null;
  user: string | null;
  uid: number | null;
  gid: number | null;
  repoDirty: boolean;
  homeDir: string;
}

export async function inspectWorkspace(repositoryRoot: string): Promise<WorkspaceState> {
  const id = await runCommand('id', []);
  const gitStatus = await runCommand('git', ['-C', repositoryRoot, 'status', '--porcelain'], { timeoutMs: 5000 });
  const gitHead = await runCommand('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD'], { timeoutMs: 5000 });
  const owner = await runCommand('whoami', [], { timeoutMs: 5000 });
  const match = id.stdout.match(/uid=(\d+)\(([^)]+)\).*gid=(\d+)\(([^)]+)\)/);
  return {
    repositoryRoot,
    checkedOut: existsSync(join(repositoryRoot, '.git')) && gitHead.exitCode === 0,
    owner: owner.stdout.trim() || null,
    user: match?.[2] ?? null,
    uid: match?.[1] ? Number(match[1]) : null,
    gid: match?.[3] ? Number(match[3]) : null,
    repoDirty: gitStatus.stdout.trim().length > 0,
    homeDir: process.env.HOME ?? '/home/coder',
  };
}

export async function checkPathAccess(path: string): Promise<boolean> {
  return existsSync(path);
}