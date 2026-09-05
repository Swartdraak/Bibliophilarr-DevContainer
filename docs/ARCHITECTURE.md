# Architecture decision record

## ADR-001: one image, filesystem, and repository checkout

**Status:** proposed; live validation required. Coder provisions one Linux container and persistent
home volume. VS Code, Rider, WebStorm, SSH, and CLI attach through the same Coder agent. A dedicated
rootless Docker-in-Docker sidecar supplies disposable test containers without exposing the host
Docker socket. The devcontainer proposal pins the same image.

```text
                 Coder control plane
                         |
          parameters + external Git auth + secrets
                         |
        +----------------+----------------+
        | Bibliophilarr workspace container|
        | /workspaces/Bibliophilarr         |
        | coder agent + canonical toolchain |
        +----+----------+----------+---------+
             |          |          |
          VS Code     Rider     WebStorm/CLI
             |          |          |
             +----------+----------+
                         |
            rootless DinD sidecar (optional)
                         |
             GitHub / registries / routed vLLM
```

## Decisions

1. **Authority separation:** image = executable capabilities; repository = agent behavior and
   policy; template = lifecycle; IDE adapter = access. Repository agents, skills, prompts, and
   instructions are never copied into the image.
2. **Persistence:** home/worktree, NuGet, and Yarn caches are distinct named volumes. Validator
   workspaces must be separately named and destroyed after evidence capture. Build/test outputs are
   not shared across workspaces.
3. **Container isolation:** no `/var/run/docker.sock`. Rootless DinD still uses a privileged sidecar
   because common Docker provisioners require it; it narrows impact to the workspace VM/host but is
   not a sandbox against a hostile host kernel. A dedicated VM provisioner is preferred for untrusted PRs.
4. **Ref correctness:** full 40-hex SHAs produce detached HEAD and are verified byte-for-byte.
   Missing branches/tags/SHAs fail; existing dirty development worktrees are preserved, never reset.
5. **Secrets:** parameters carry identifiers and URLs only. Secret values arrive from Coder user
   secrets or a mode-scoped external secret broker. Validator mode receives no write/admin/release secret.

6. **Operational control layer:** CoderOps under `coderops/` is the canonical policy and MCP/control plane layer. It discovers Coder, inspects state, detects drift, and generates adapters; it does not replace the Coder deployment or the workspace image.

## Source of truth

| Concern | Authority |
|---|---|
| Image contents/version | this project, `toolchain.json` and immutable release |
| Coder lifecycle | `template/` |
| Project devcontainer | future Bibliophilarr `.devcontainer/` |
| .NET version | Bibliophilarr `global.json`/project contract (discovery blocked) |
| Node/Yarn | Bibliophilarr `package.json` and lockfile (discovery blocked) |
| Build/test commands | Bibliophilarr scripts |
| Agents/skills/instructions | Bibliophilarr `.github/` and scoped `AGENTS.md` |
| MCP installed software | workspace image release |
| MCP enabled/authorized tools | mode profile + repository governance |
| Secrets | Coder/external secret manager |
| vLLM endpoint/model | non-secret template parameter |
| vLLM API key | secret manager |
| CoderOps policy/schemas/agents | `coderops/` canonical sources |
| CoderOps generated adapters | `coderops/adapters/generated`, `.github/agents`, `.github/skills`, `.agents/skills` |

## Network boundaries

Outbound routes are required to GitHub, NuGet, npm/Yarn, the image registry, Coder, and the operator-
selected vLLM URL. No inbound vLLM exposure is required. Internal TLS uses an operator-mounted CA
and `update-ca-certificates`; globally disabling verification is forbidden. Egress policy should deny
metadata services and unapproved destinations, especially in validator mode.
