import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { runCommand } from './command-runner.js';

export interface GitState {
  repository: string;
  branch: string;
  commit: string;
  dirty: boolean;
  remoteUrl: string | null;
}

export async function getGitState(repositoryRoot: string): Promise<GitState> {
  if (!existsSync(join(repositoryRoot, '.git'))) {
    return {
      repository: repositoryRoot,
      branch: 'unknown',
      commit: 'unknown',
      dirty: false,
      remoteUrl: null,
    };
  }
  const branch = await runCommand('git', ['-C', repositoryRoot, 'branch', '--show-current']);
  const commit = await runCommand('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD']);
  const status = await runCommand('git', ['-C', repositoryRoot, 'status', '--porcelain']);
  const remote = await runCommand('git', ['-C', repositoryRoot, 'remote', 'get-url', 'origin']);
  return {
    repository: repositoryRoot,
    branch: branch.stdout.trim() || 'detached',
    commit: commit.stdout.trim() || 'unknown',
    dirty: status.stdout.trim().length > 0,
    remoteUrl: remote.exitCode === 0 ? remote.stdout.trim() : null,
  };
}

export async function hasGitRepository(repositoryRoot: string): Promise<boolean> {
  return existsSync(join(repositoryRoot, '.git'));
}