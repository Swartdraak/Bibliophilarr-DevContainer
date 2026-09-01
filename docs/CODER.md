# Coder deployment and user workflows

Target URL: `https://coder.onyxfang.info`; template: `bibliophilarr-agent-workspace`. The 2026-09-01
execution environment could not reach it: the outbound proxy returned HTTP 403 before authentication.
Therefore server version, provisioner topology, template history, and deployment remain **BLOCKED**.
The supplied management credential was not persisted, printed, committed, or injected into a workspace.

After network access is restored, an operator injects `CODER_URL` and the officially supported session
token variable into the process environment, records `coder version`, provisioners, templates, and the
existing rollback version, then runs `validate-template.sh`. Publishing is additive:
`coder templates push bibliophilarr-agent-workspace -d template`. Never pass the management token as a
Terraform variable or container environment variable.

For development select `bibliophilarr_ref=develop`, `workspace_mode=development`, and open the single
workspace through VS Code, SSH, Rider, or WebStorm. For validation select a full SHA and `validator`.
For staging QA select `staging`, `staging-validation`, and read-only media, then ask the repository
orchestrator to delegate validation. Coder stop/start preserves the named home/caches; container scratch
is ephemeral. Each validator must use a separately named workspace.
