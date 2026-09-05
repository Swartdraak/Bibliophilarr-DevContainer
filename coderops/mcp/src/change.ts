import { randomUUID } from 'node:crypto';
import type { ChangePlan, ChangeResult, RiskLevel, VerificationResult } from './types.js';
import { requireApproval, riskAllowed } from './policy.js';
import { auditOperation, recordPlan, recordResult } from './audit.js';

export function createChangePlan(target: string, currentState: string, desiredState: string, operations: string[], risk: RiskLevel, requestedBy = 'unknown'): ChangePlan {
  return {
    id: `chg-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}-${randomUUID().slice(0, 8)}`,
    created_at: new Date().toISOString(),
    requested_by: requestedBy,
    target,
    current_state: currentState,
    desired_state: desiredState,
    operations,
    risk,
    expected_impact: 'Policy-controlled operational change',
    preconditions: [],
    validation: [],
    rollback: [],
    requires_approval: requireApproval(risk),
    approval_scope: risk,
    status: 'draft',
  };
}

export async function applyChange(plan: ChangePlan, mode: 'observer' | 'operator' | 'administrator', allowR3 = false, allowR4 = false): Promise<ChangeResult> {
  await recordPlan(plan);
  if (!riskAllowed(mode, plan.risk, allowR3, allowR4)) {
    const result: ChangeResult = {
      planId: plan.id,
      status: 'failed',
      started_at: new Date().toISOString(),
      finished_at: new Date().toISOString(),
      result: 'blocked by policy',
      verification: 'not-run',
    };
    await recordResult(result);
    return result;
  }
  const result: ChangeResult = {
    planId: plan.id,
    status: 'applied',
    started_at: new Date().toISOString(),
    finished_at: new Date().toISOString(),
    result: 'no-op placeholder apply path',
    verification: 'manual verification required',
  };
  await auditOperation({ planId: plan.id, operation: 'apply', target: plan.target, risk: plan.risk, mode });
  await recordResult(result);
  return result;
}

export function verifyChange(plan: ChangePlan): VerificationResult {
  return {
    target: plan.target,
    status: 'unknown',
    checkedAt: new Date().toISOString(),
    evidence: [],
    findings: [],
  };
}