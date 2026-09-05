import type { CoderOpsConfig } from './types.js';
import { inspectCapabilities } from './capabilities.js';
import { inspectTemplate } from './template.js';
import { inspectWorkspace } from './workspace.js';
import { inspectAi } from './ai.js';
import { inspectHost } from './host.js';
import { getGitState } from './git.js';

export interface HealthReport {
  overall: 'PASS' | 'DEGRADED' | 'FAIL';
  sections: Array<{ name: string; status: 'PASS' | 'DEGRADED' | 'FAIL' | 'UNKNOWN'; details: string }>;
  findings: string[];
}

export async function inspectHealth(config: CoderOpsConfig): Promise<HealthReport> {
  const git = await getGitState(config.repository.root);
  const workspace = await inspectWorkspace(config.repository.root);
  const template = await inspectTemplate(`${config.repository.root}/${config.repository.templatePath}`);
  const capabilities = await inspectCapabilities(config);
  const ai = await inspectAi();
  const host = await inspectHost();
  const sections = [
    { name: 'Coder CLI', status: capabilities.coder.cli_version !== 'unknown' ? 'PASS' : 'FAIL', details: capabilities.coder.cli_version },
    { name: 'Template', status: template.validate ? 'PASS' : 'DEGRADED', details: template.workspaceImage ?? 'unknown' },
    { name: 'Workspace', status: workspace.checkedOut ? 'PASS' : 'FAIL', details: workspace.homeDir },
    { name: 'AI', status: ai.enabled ? (ai.reachable ? 'PASS' : 'DEGRADED') : 'UNKNOWN', details: ai.provider ?? 'none' },
    { name: 'Host', status: host.docker ? 'PASS' : 'UNKNOWN', details: host.deployment_method },
    { name: 'Git', status: git.commit !== 'unknown' ? 'PASS' : 'FAIL', details: git.commit },
  ] as const;
  const failures = sections.filter((section) => section.status === 'FAIL').length;
  const degraded = sections.filter((section) => section.status === 'DEGRADED').length;
  return {
    overall: failures > 0 ? 'FAIL' : degraded > 0 ? 'DEGRADED' : 'PASS',
    sections: [...sections],
    findings: [],
  };
}