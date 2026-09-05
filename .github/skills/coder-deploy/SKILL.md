---
name: coder-deploy
description: Deploy, validate, and promote the Bibliophilarr Coder template using the repository-first workflow and required live validation steps.
argument-hint: 'Describe the deployment target, candidate version, or validation task (for example: "push a template fix candidate for v2.4 and validate a disposable workspace")'
user-invocable: true
---

# Coder deployment workflow

Use this skill for any template publication or workspace validation work.

## Required sequence

1. Read the repo-local `.env` values and run `./scripts/verify-coder-auth`.
2. Confirm the Coder server is authenticated before any `coder` or template command.
3. Validate the repo locally with `./scripts/validate-template.sh`.
4. Push a new inactive version using `./scripts/publish-coder-template.sh push --name <name>`.
5. Create a disposable validation workspace with `./scripts/publish-coder-template.sh create-ws --version <name> --ws <workspace-name>`.
6. Validate the workspace using the repo checklist and real runtime evidence.
7. Promote only after the validation passes.
8. Verify the live version is now Active.
9. Delete the validation workspace if cleanup is required.

## Important policy

- The repository is not the deployment. Deployment occurs only when the live Coder server confirms the push.
- Never skip the fresh-workspace validation step.
- Never auto-promote a candidate version.
- Never claim success without output from the live Coder CLI.

## Typical commands

```bash
./scripts/verify-coder-auth
./scripts/validate-template.sh
./scripts/publish-coder-template.sh push --name v2.4
./scripts/publish-coder-template.sh create-ws --version v2.4 --ws validation-v2-4
./scripts/publish-coder-template.sh promote --version v2.4
```

## Failure handling

- If `coder whoami` fails, do not proceed.
- If the template still shows the old image tag on the live server, treat that as an unpatched deployment and report it clearly.
- If only repo files changed and the live server did not move, the correct status is “not deployed.”
