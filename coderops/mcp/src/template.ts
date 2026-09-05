import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { runCommand } from './command-runner.js';

export interface TemplateState {
  path: string;
  fmt: boolean;
  validate: boolean;
  files: string[];
  workspaceImage: string | null;
  toolchainVersion: string | null;
  gitSha: string | null;
}

export async function inspectTemplate(templateRoot: string): Promise<TemplateState> {
  const fmt = await runCommand('terraform', ['-chdir', templateRoot, 'fmt', '-check', '-recursive'], { timeoutMs: 20_000 });
  const init = await runCommand('terraform', ['-chdir', templateRoot, 'init', '-backend=false'], { timeoutMs: 60_000 });
  const validate = await runCommand('terraform', ['-chdir', templateRoot, 'validate'], { timeoutMs: 60_000 });
  const files = ['main.tf', 'variables.tf', 'versions.tf', 'outputs.tf'].filter((file) => existsSync(join(templateRoot, file)));
  let workspaceImage: string | null = null;
  const variablesPath = join(templateRoot, 'variables.tf');
  if (existsSync(variablesPath)) {
    const content = readFileSync(variablesPath, 'utf8');
    const match = content.match(/ghcr\.io\/[^\"]+/);
    workspaceImage = match?.[0] ?? null;
  }
  return {
    path: templateRoot,
    fmt: fmt.exitCode === 0,
    validate: init.exitCode === 0 && validate.exitCode === 0,
    files,
    workspaceImage,
    toolchainVersion: null,
    gitSha: null,
  };
}

export async function compareTemplateVersions(repoTemplateImage: string | null, configuredImage: string | null): Promise<boolean> {
  return repoTemplateImage !== null && configuredImage !== null && repoTemplateImage === configuredImage;
}