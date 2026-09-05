import { compareTemplateVersions } from './template.js';
import type { GitState } from './git.js';

export interface DriftReport {
  generated_at: string;
  repository_commit: string | null;
  template_source_fingerprint: string | null;
  active_coder_template_version: string | null;
  latest_coder_template_version: string | null;
  workspace_template_version: string | null;
  status: 'synced' | 'drifted' | 'unknown';
  notes: string[];
}

export async function detectDrift(git: GitState, repoTemplateImage: string | null, activeVersion: string | null, workspaceVersion: string | null): Promise<DriftReport> {
  const synced = await compareTemplateVersions(repoTemplateImage, workspaceVersion);
  const status = synced ? 'synced' : 'drifted';
  return {
    generated_at: new Date().toISOString(),
    repository_commit: git.commit,
    template_source_fingerprint: repoTemplateImage,
    active_coder_template_version: activeVersion,
    latest_coder_template_version: null,
    workspace_template_version: workspaceVersion,
    status,
    notes: [],
  };
}