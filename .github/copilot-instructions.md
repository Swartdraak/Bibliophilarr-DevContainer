# Bibliophilarr repo operating instructions

This repository is the canonical source for the Bibliophilarr Coder workspace image and template. It does not directly mutate the live Coder deployment. Any template-affecting change is only complete after the exact repository source is pushed to Coder, validated in a fresh disposable workspace, and promoted to Active.

## Required operating rules

1. Treat the repository as the source of truth; never assume the live Coder deployment is current.
2. Before any `coder` command, run the repo auth preflight: `./scripts/verify-coder-auth`.
3. Use the repo-local `.env` values as the credential source. Never prefer a stale global `~/.config/coder.json` session over the repository config.
4. Never print, log, or expose `CODER_TOKEN`, `CODER_SESSION_TOKEN`, or any secret material.
5. A template-affecting change is not done until the exact repo content has been pushed, exercised through a fresh workspace, and promoted only after validation succeeds.
6. If the Coder environment is unauthenticated, report that exact condition and stop. Do not claim deployment success without evidence from the live CLI.
7. Keep logs explicit and traceable: record template name, version, git SHA, and validation status.

## Repository layout and responsibilities

- `template/`: Terraform source for the Coder workspace template
- `image/`: workspace container and image build metadata
- `scripts/`: deployment, validation, and runtime helper scripts
- `workspace/bin/`: runtime utilities used by the workspace
- `docs/`: design, runbook, acceptance, and operator notes
- `.env`: repository-local Coder credentials and local LLM settings

## Required checks before deployment

- Validate the template locally before any push: `./scripts/validate-template.sh`
- Run `./scripts/verify-coder-auth` before any `coder templates ...` or `coder create ...` command
- Verify the active template and version list only after auth succeeds
- Push as a new inactive candidate; do not auto-activate
- Create a fresh disposable workspace from the candidate version
- Validate the workspace end-to-end and only then promote it
- Delete the disposable workspace after validation if required by policy

## Build and validation expectations

- Prefer deterministic, pinned versions for toolchains and JetBrains builds when the repo policy requires it
- Reconcile the repo image tag, template default image, and live Coder template default before claiming the deployment is aligned
- If a failure is caused by the app repository rather than this repo, clearly separate the root cause from the workspace platform issue
- For Rider, WebStorm, and other IDE issues, check the actual client install metadata and the app project build target separately from the Coder template deployment

## Safety

- Never assume a template is deployed because a file changed in Git
- Never claim success without a fresh CLI result from the actual Coder environment
- Never bypass the repo auth helper or the repository-first deployment workflow
