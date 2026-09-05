import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { defaultConfig, discoverRepositoryRoot, loadConfig } from './config.js';
import { createLogger, stateDir } from './logging.js';
import { inspectInventory } from './inventory.js';
import { inspectCapabilities } from './capabilities.js';
import { inspectHealth } from './health.js';
import { ensureAuditLayout } from './audit.js';

async function writeJson(path: string, value: unknown): Promise<void> {
  await mkdir(join(path, '..'), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function readMaybeConfig(): Promise<ReturnType<typeof defaultConfig>> {
  const repositoryRoot = discoverRepositoryRoot();
  const configPath = process.env.CODEROPS_CONFIG ?? join(repositoryRoot, 'coderops.example.yaml');
  try {
    return await loadConfig(configPath);
  } catch {
    return defaultConfig(process.env.CODEROPS_REPOSITORY_ROOT ?? repositoryRoot);
  }
}

function printHuman(title: string, body: Record<string, unknown>): void {
  // eslint-disable-next-line no-console
  console.log(`${title}`);
  for (const [key, value] of Object.entries(body)) {
    // eslint-disable-next-line no-console
    console.log(`  ${key}: ${typeof value === 'object' ? JSON.stringify(value) : String(value)}`);
  }
}

async function commandDoctor(json = false): Promise<number> {
  const config = await readMaybeConfig();
  const inventory = await inspectInventory(config);
  const health = await inspectHealth(config);
  const capabilities = await inspectCapabilities(config, inventory.coder.health === 'authenticated', inventory.coder.organization, inventory.coder.version);
  const report = { inventory, health, capabilities };
  if (json) {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(report, null, 2));
  } else {
    printHuman('CODEROPS DOCTOR', {
      overall: health.overall,
      coder: inventory.coder.health,
      template: inventory.bibliophilarr.drift,
      workspace: inventory.workspace.repoDirty ? 'dirty' : 'clean',
      ai: inventory.ai.enabled ? (inventory.ai.reachable ? 'reachable' : 'configured') : 'disabled',
      mcp: capabilities.capabilities.native_mcp ? 'available' : 'unavailable',
      mode: config.mode,
    });
  }
  return health.overall === 'PASS' ? 0 : health.overall === 'DEGRADED' ? 1 : 2;
}

async function commandInventory(json = false): Promise<number> {
  const config = await readMaybeConfig();
  const inventory = await inspectInventory(config);
  if (json) {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(inventory, null, 2));
  } else {
    printHuman('CODEROPS INVENTORY', {
      repo: inventory.git.repository,
      branch: inventory.git.branch,
      commit: inventory.git.commit,
      dirty: inventory.git.dirty,
      ai: inventory.ai.enabled ? inventory.ai.provider ?? 'configured' : 'disabled',
      mode: config.mode,
    });
  }
  return 0;
}

async function commandCapabilities(json = false): Promise<number> {
  const config = await readMaybeConfig();
  const inventory = await inspectInventory(config);
  const capabilities = await inspectCapabilities(config, inventory.coder.health === 'authenticated', inventory.coder.organization, inventory.coder.version);
  if (json) {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(capabilities, null, 2));
  } else {
    printHuman('CODEROPS CAPABILITIES', {
      native_mcp: capabilities.capabilities.native_mcp,
      remote_mcp: capabilities.capabilities.remote_mcp,
      coder_agents: capabilities.capabilities.coder_agents,
      ai: capabilities.capabilities.ai,
      templates: capabilities.capabilities.template_api,
      workspaces: capabilities.capabilities.workspace_api,
      users: capabilities.capabilities.user_api,
      provisioners: capabilities.capabilities.provisioner_api,
      docker: capabilities.capabilities.docker,
    });
  }
  return 0;
}

async function commandGenerateAdapters(): Promise<number> {
  const generated = stateDir() + '/adapters.json';
  await ensureAuditLayout();
  await writeJson(generated, {
    generated_at: new Date().toISOString(),
    note: 'Run coderops/scripts/generate-adapters.sh for full generated adapters',
  });
  // eslint-disable-next-line no-console
  console.log(`generated ${generated}`);
  return 0;
}

export async function runCli(argv = process.argv.slice(2)): Promise<number> {
  const [cmd = 'doctor', ...rest] = argv;
  const json = rest.includes('--json');
  switch (cmd) {
    case 'doctor':
      return await commandDoctor(json);
    case 'inventory':
      return await commandInventory(json);
    case 'capabilities':
      return await commandCapabilities(json);
    case 'generate-adapters':
      return await commandGenerateAdapters();
    default:
      // eslint-disable-next-line no-console
      console.error(`unknown command: ${cmd}`);
      return 3;
  }
}

if (import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  void runCli().then((code) => {
    process.exitCode = code;
  });
}