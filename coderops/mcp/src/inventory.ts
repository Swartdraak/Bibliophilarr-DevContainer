import type { CoderOpsConfig } from './types.js';
import { getGitState } from './git.js';
import { inspectCapabilities } from './capabilities.js';
import { inspectAi } from './ai.js';
import { inspectWorkspace } from './workspace.js';
import { inspectHost } from './host.js';
import { inspectTemplate } from './template.js';
import { whoAmI } from './coder-cli.js';

export interface InventorySnapshot {
  generated_at: string;
  coder: {
    version: string | null;
    url: string | null;
    organization: string | null;
    health: string;
  };
  capabilities: Awaited<ReturnType<typeof inspectCapabilities>>['capabilities'];
  users: { visible_count: number; admins: string[]; warnings: string[] };
  templates: Array<{ name: string; id: string | null; active_version: string | null; latest_version: string | null; provisioner: string | null; workspaces: number | null; drift: string | null }>;
  workspaces: { running: number; stopped: number; failed: number; total: number };
  provisioners: { healthy: number; unavailable: number; total: number };
  ai: Awaited<ReturnType<typeof inspectAi>>;
  runtime: Awaited<ReturnType<typeof inspectHost>>;
  git: Awaited<ReturnType<typeof getGitState>>;
  bibliophilarr: { template_path: string; template_source_commit: string | null; deployed_template_version: string | null; drift: string };
  workspace: Awaited<ReturnType<typeof inspectWorkspace>>;
}

export async function inspectInventory(config: CoderOpsConfig): Promise<InventorySnapshot> {
  const git = await getGitState(config.repository.root);
  const auth = await whoAmI();
  const capabilities = await inspectCapabilities(config, auth.authenticated, null, null);
  const ai = await inspectAi();
  const runtime = await inspectHost();
  const workspace = await inspectWorkspace(config.repository.root);
  const template = await inspectTemplate(`${config.repository.root}/${config.repository.templatePath}`);
  return {
    generated_at: new Date().toISOString(),
    coder: {
      version: capabilities.coder.cli_version,
      url: process.env.CODER_URL ?? null,
      organization: capabilities.coder.organization,
      health: auth.authenticated ? 'authenticated' : 'unauthenticated',
    },
    capabilities: capabilities.capabilities,
    users: {
      visible_count: auth.authenticated ? 1 : 0,
      admins: [],
      warnings: auth.authenticated ? [] : ['Coder authentication not available'],
    },
    templates: [
      {
        name: 'Bibliophilarr',
        id: null,
        active_version: null,
        latest_version: null,
        provisioner: null,
        workspaces: null,
        drift: template.workspaceImage ? (git.commit ? 'unknown' : 'unknown') : 'unknown',
      },
    ],
    workspaces: { running: 0, stopped: 0, failed: 0, total: 0 },
    provisioners: { healthy: 0, unavailable: 0, total: 0 },
    ai,
    runtime,
    git,
    bibliophilarr: {
      template_path: config.repository.templatePath,
      template_source_commit: config.bibliophilarr?.templateSourceCommit ?? git.commit,
      deployed_template_version: null,
      drift: 'unknown',
    },
    workspace,
  };
}