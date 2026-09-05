import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import YAML from 'yaml';
import { z } from 'zod';
import type { CoderOpsConfig } from './types.js';

export const coderOpsConfigSchema = z.object({
  schemaVersion: z.literal(1),
  coder: z.object({
    urlFromEnv: z.string().optional(),
    auth: z.object({
      mode: z.enum(['existing-cli', 'session-token', 'oauth', 'env-token']).optional(),
      tokenEnv: z.string().optional(),
    }).optional(),
  }),
  mode: z.enum(['observer', 'operator', 'administrator']),
  repository: z.object({
    root: z.string(),
    templatePath: z.string(),
  }),
  bibliophilarr: z.object({
    workspaceRepository: z.string().optional(),
    templateSourceCommit: z.string().optional(),
  }).optional(),
  runtime: z.object({
    type: z.enum(['auto', 'docker', 'docker-compose', 'systemd', 'kubernetes', 'unknown']).optional(),
  }).optional(),
  policy: z.object({
    allowR3: z.boolean().optional(),
    allowR4: z.boolean().optional(),
  }).optional(),
  audit: z.object({
    enabled: z.boolean().optional(),
  }).optional(),
  mcp: z.object({
    preferNativeCoder: z.boolean().optional(),
  }).optional(),
});

export async function loadConfig(configPath = join(process.cwd(), 'coderops.example.yaml')): Promise<CoderOpsConfig> {
  const raw = await readFile(configPath, 'utf8');
  const parsed = YAML.parse(raw) as unknown;
  return coderOpsConfigSchema.parse(parsed) as CoderOpsConfig;
}

export function discoverRepositoryRoot(startDir = process.cwd()): string {
  let current = startDir;
  while (current !== dirname(current)) {
    if (existsSync(join(current, 'template', 'main.tf')) || existsSync(join(current, '.git'))) {
      return current;
    }
    current = dirname(current);
  }
  return startDir;
}

export function defaultConfig(repositoryRoot: string): CoderOpsConfig {
  return {
    schemaVersion: 1,
    coder: {
      urlFromEnv: 'CODER_URL',
      auth: {
        mode: 'existing-cli',
        tokenEnv: 'CODER_SESSION_TOKEN',
      },
    },
    mode: 'observer',
    repository: {
      root: repositoryRoot,
      templatePath: 'template',
    },
    runtime: {
      type: 'auto',
    },
    policy: {
      allowR3: false,
      allowR4: false,
    },
    audit: {
      enabled: true,
    },
    mcp: {
      preferNativeCoder: true,
    },
  };
}

export function resolveRepositoryRoot(config?: Partial<CoderOpsConfig>): string {
  return config?.repository?.root ?? process.env.CODEROPS_REPOSITORY_ROOT ?? discoverRepositoryRoot();
}