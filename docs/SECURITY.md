# Security and threat model

| Threat | Boundary/impact | Required mitigation |
|---|---|---|
| Malicious repo or PR code | workspace, credentials, network | disposable validator VM/workspace; read-only clone credential; deny unrelated egress; no production/release secrets |
| Docker daemon escalation | sidecar/host kernel | never mount host socket; prefer dedicated VM; rootless DinD; destroy validator after run |
| MCP compromise | files/GitHub/model context | allowlisted pinned servers; mode profiles; read-only variants; log startup; no global catalog |
| Prompt injection | agent authority | repository governance, human review, minimal tools, never treat content as authorization |
| Over-scoped GitHub token | repository/org | Coder external auth with minimum scopes; validator read-only deploy/app credential; no admin token |
| Secret exfiltration | logs/process/network | no secret parameters; `umask 077`; redacted logs; block env/credential dumps; egress controls |
| Shared/persistent volume contamination | next run/user | per-owner/workspace volumes; fresh validator; documented cache purge; never share worktree |
| Supply-chain package/image | arbitrary execution | pinned digest, lockfiles, SBOM (Syft), Trivy scan, signed immutable release, review updates |
| Untrusted IDE extension/plugin | developer credentials | managed allowlist, publisher trust, no auto-install beyond reviewed recommendations |
| Workspace sharing | cross-user disclosure | owner-only access, Coder RBAC, no shared user secrets, audit access |
| Exposed local vLLM | data/model theft | routed private endpoint, TLS/internal CA, auth, firewall, no hardcoded IP |

## Credential profile

| Mode | GitHub | vLLM | Forbidden |
|---|---|---|---|
| development | user external auth, repository-scoped write | optional | admin/release/production |
| ci-repair | repository read/write as needed | optional | repository admin |
| governance | metadata/workflow scope only when approved | optional | application/release authority |
| investigation | read-only | optional | push/write |
| validator | read-only app/deploy credential | only if test requires | all write, admin, release, infrastructure and production secrets |
| release-validation | read/review | optional | publish/sign until a separate human-authorized step |

Coder user secrets may be available to every workspace owned by that user depending on deployment
configuration. That is unacceptable for validator isolation when the user owns privileged secrets.
Use a mode-aware external broker/workload identity or a separate least-privileged validator identity.
Do not test secrets by printing value, length, prefix, helper output, or headers; test only whether the
expected integration succeeds.

CoderOps adds explicit risk classes R0-R4, observer/operator/administrator modes, and approval-gated change plans. Administrative tools must reject blind mutation requests and keep the audit log secret-safe.
