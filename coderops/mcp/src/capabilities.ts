import type { CoderOpsConfig } from './types.js';
import { inspectCoderCli } from './coder-cli.js';
import { inspectNativeCoderMcp } from './native-mcp.js';
import { inspectHost } from './host.js';

export interface CapabilitySnapshot {
  generated_at: string;
  coder: {
    cli_version: string;
    server_version: string | null;
    authenticated: boolean;
    organization: string | null;
  };
  capabilities: {
    native_mcp: boolean;
    remote_mcp: boolean;
    coder_agents: boolean;
    ai: boolean;
    template_api: boolean;
    workspace_api: boolean;
    user_api: boolean;
    provisioner_api: boolean;
    host_access: boolean;
    git_access: boolean;
    terraform: boolean;
    docker: boolean;
  };
  mode: string;
}

export async function inspectCapabilities(config: CoderOpsConfig, authenticated = false, organization: string | null = null, serverVersion: string | null = null): Promise<CapabilitySnapshot> {
  const cli = await inspectCoderCli();
  const nativeMcp = await inspectNativeCoderMcp();
  const host = await inspectHost();
  return {
    generated_at: new Date().toISOString(),
    coder: {
      cli_version: cli.version,
      server_version: serverVersion,
      authenticated,
      organization,
    },
    capabilities: {
      native_mcp: nativeMcp.available,
      remote_mcp: nativeMcp.remote_http,
      coder_agents: true,
      ai: host.envNames.some((name) => /LLM|COPILOT/i.test(name)),
      template_api: cli.templatesHelp.length > 0,
      workspace_api: cli.workspacesHelp.length > 0,
      user_api: authenticated,
      provisioner_api: cli.provisionerHelp.length > 0,
      host_access: true,
      git_access: true,
      terraform: true,
      docker: host.docker,
    },
    mode: config.mode,
  };
}