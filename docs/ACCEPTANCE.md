# Acceptance matrix

Evidence date: 2026-09-06.

| Capability | Result | Evidence/blocker |
|---|---|---|
| Startup health false-positive remediation | PASS | Root cause confirmed: startup checks could exceed default command runtime and surface false-negative health results during slow git/verification operations; deterministic timeouts and bounded execution added in startup, checkout, and smoke-check flows |
| Deterministic timeout hardening | PASS | `WORKSPACE_GIT_TIMEOUT_SEC` (default 180), `WORKSPACE_CHECK_TIMEOUT_SEC` (default 60), `WORKSPACE_VERIFY_TIMEOUT_SEC` (default 120), and `run_with_timeout` guards applied to clone/fetch/checkout/verify/smoke operations |
| Startup and checkout non-interactive safety | PASS | `GIT_TERMINAL_PROMPT=0` enforced in startup and checkout flows to prevent interactive credential prompts from stalling startup health |
| Post-start smoke checks and evidence surfacing | PASS | Template now runs bounded startup smoke checks (`coder_script`) and exposes logs via `workspace-logs` app with startup and smoke log tails |
| Validation flow (fresh candidate workspace) | PASS | v2.8 candidate validated on a clean disposable workspace with healthy startup completion, smoke checks produced, and no startup-health false-positive reported |
| Branch/exact SHA/dirty-worktree checkout | PASS | checkout policy and tests remain aligned with hardened timeout flow |

No blocked or untested item is represented as a pass.
