export type RiskLevel = 'R0' | 'R1' | 'R2' | 'R3' | 'R4';
export type Mode = 'observer' | 'operator' | 'administrator';
export type Severity = 'info' | 'warning' | 'error' | 'critical';
export type OperationStatus = 'PASS' | 'FAIL' | 'BLOCKED' | 'NOT-TESTED' | 'NOT-APPLICABLE' | 'DEGRADED' | 'UNKNOWN';

export interface CoderOpsConfig {
  schemaVersion: 1;
  coder: {
    urlFromEnv?: string;
    auth?: {
      mode?: 'existing-cli' | 'session-token' | 'oauth' | 'env-token';
      tokenEnv?: string;
    };
  };
  mode: Mode;
  repository: {
    root: string;
    templatePath: string;
  };
  bibliophilarr?: {
    workspaceRepository?: string;
    templateSourceCommit?: string;
  };
  runtime?: {
    type?: 'auto' | 'docker' | 'docker-compose' | 'systemd' | 'kubernetes' | 'unknown';
  };
  policy?: {
    allowR3?: boolean;
    allowR4?: boolean;
  };
  audit?: {
    enabled?: boolean;
  };
  mcp?: {
    preferNativeCoder?: boolean;
  };
}

export interface CommandResult {
  command: string;
  args: string[];
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
  timedOut: boolean;
}

export interface DiagnosticFinding {
  id: string;
  severity: Severity;
  domain: string;
  summary: string;
  evidence: string[];
  hypothesis: string | null;
  recommendedAction: string;
  autoRepairable: boolean;
  risk: RiskLevel;
}

export interface ChangePlan {
  id: string;
  created_at: string;
  requested_by: string;
  target: string;
  current_state: string;
  desired_state: string;
  operations: string[];
  risk: RiskLevel;
  expected_impact: string;
  preconditions: string[];
  validation: string[];
  rollback: string[];
  requires_approval: boolean;
  approval_scope: string;
  status: 'draft' | 'planned' | 'approved' | 'applied' | 'verified' | 'rolled_back' | 'failed';
}

export interface ChangeResult {
  planId: string;
  status: 'applied' | 'failed' | 'rolled_back';
  started_at: string;
  finished_at: string;
  result: string;
  verification: string;
}

export interface VerificationResult {
  target: string;
  status: 'pass' | 'fail' | 'blocked' | 'unknown';
  checkedAt: string;
  evidence: string[];
  findings: DiagnosticFinding[];
}