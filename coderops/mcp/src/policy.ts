import type { Mode, RiskLevel } from './types.js';

export function riskAllowed(mode: Mode, risk: RiskLevel, allowR3 = false, allowR4 = false): boolean {
  if (mode === 'observer') {
    return risk === 'R0';
  }
  if (mode === 'operator') {
    return risk === 'R0' || risk === 'R1' || risk === 'R2';
  }
  if (risk === 'R4') {
    return allowR4;
  }
  if (risk === 'R3') {
    return allowR3;
  }
  return true;
}

export function requireApproval(risk: RiskLevel): boolean {
  return risk === 'R3' || risk === 'R4';
}

export function classifyMutation(kind: string): RiskLevel {
  if (/delete|destroy|drop|restore|reset/i.test(kind)) return 'R4';
  if (/upgrade|activate|restart|publish/i.test(kind)) return 'R3';
  if (/start|stop|refresh|repair/i.test(kind)) return 'R1';
  return 'R0';
}