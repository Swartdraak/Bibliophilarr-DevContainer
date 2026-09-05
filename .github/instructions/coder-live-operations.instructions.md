# Coder live operations

Apply these instructions whenever working with the live Bibliophilarr Coder instance or its managed workspaces.

## Always do this first

- Use the repository-local credentials in `.env`.
- Run `./scripts/verify-coder-auth` before any `coder` action.
- Confirm the CLI is authenticated and the target organization is available.

## Never do this

- Never treat the repo diff as a deployment.
- Never trust `~/.config/coder.json` over `.env`.
- Never print tokens, URLs with embedded credentials, or secrets.
- Never say a fix is live unless the CLI confirms the template version and Active state.
- Never skip the disposable validation workspace.

## Deployment discipline

- push a candidate version as inactive
- validate via a fresh workspace
- promote only after pass
- verify the Active version
- clean up the disposable workspace if required

## Workspace troubleshooting

- Check startup logs, repo checkout, and runtime version alignment before chasing IDE issues
- Distinguish deployment drift from app-specific build issues
- For Rider failures, check the actual project target and Windows Desktop requirements separately from the Coder operation
- For JetBrains app issues, confirm the live install metadata and pinned build values against the current JetBrains release API

## Evidence standard

Every live deployment or troubleshooting claim must be backed by fresh command output from the Coder CLI or workspace runtime. No assumptions, no “should be fixed,” no silent restatements.
