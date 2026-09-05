import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { stateDir, writeJsonl } from './logging.js';
import type { ChangePlan, ChangeResult } from './types.js';

export async function ensureAuditLayout(): Promise<void> {
  await mkdir(join(stateDir(), 'changes'), { recursive: true });
  await mkdir(join(stateDir(), 'plans'), { recursive: true });
  await mkdir(join(stateDir(), 'reports'), { recursive: true });
}

export async function auditOperation(entry: Record<string, unknown>): Promise<void> {
  await ensureAuditLayout();
  await writeJsonl({
    timestamp: new Date().toISOString(),
    level: 'info',
    message: 'coderops-operation',
    fields: entry,
  });
}

export async function recordPlan(plan: ChangePlan): Promise<void> {
  await ensureAuditLayout();
  await writeJsonl({
    timestamp: plan.created_at,
    level: 'info',
    message: 'coderops-plan',
    fields: plan as unknown as Record<string, unknown>,
  });
}

export async function recordResult(result: ChangeResult): Promise<void> {
  await ensureAuditLayout();
  await writeJsonl({
    timestamp: new Date().toISOString(),
    level: 'info',
    message: 'coderops-result',
    fields: result as unknown as Record<string, unknown>,
  });
}