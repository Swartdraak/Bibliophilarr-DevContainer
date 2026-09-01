# Discovery record and version assumptions

Discovery ran on 2026-08-31 without mutating a live service or Bibliophilarr repository.

| Item | Result |
|---|---|
| Local Coder CLI/server | Not present; no `CODER_URL` or session supplied |
| Provisioner/runtime | Not discoverable; Docker template is an explicit assumption |
| Local Docker | CLI/daemon not present |
| Coder hostname/topology | Not supplied |
| Registry | GHCR is a placeholder, not an approved registry decision |
| External auth/user secrets | No live configuration accessible |
| Bibliophilarr repository | HTTPS clone blocked by environment proxy (403) |
| Documentation research | Web search service returned 401; direct HTTPS returned proxy 403 |

Consequently the image's .NET 8 and Node 20 values are **provisional**, not claims about repository
truth. Before release, compare `global.json`, all solution/project/package/lock files, build scripts,
compose files, tests, workflows, and repository agent/governance files. Update `toolchain.json`, build
a new semantic version, and never mutate `0.2.0`.

## Authoritative sources to re-check at deployment time

* [Coder version support](https://coder.com/docs/reference/cli/server)
* [Coder Docker templates](https://coder.com/docs/admin/templates/extending-templates/docker-in-workspaces)
* [Coder Terraform provider](https://registry.terraform.io/providers/coder/coder/latest/docs)
* [Coder registry modules](https://registry.coder.com/)
* [Coder external authentication](https://coder.com/docs/admin/external-auth)
* [Coder user secrets](https://coder.com/docs/admin/templates/user-secrets)
* [Coder JetBrains](https://coder.com/docs/user-guides/workspace-access/jetbrains)
* [Coder VS Code](https://coder.com/docs/user-guides/workspace-access/vscode)
* [Dev Container specification](https://containers.dev/implementors/spec/)
* [GitHub Copilot CLI BYOK](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/use-byok)
* [VS Code language model configuration](https://code.visualstudio.com/docs/copilot/language-models)
* [JetBrains AI model configuration](https://www.jetbrains.com/help/ai-assistant/configure-an-llm.html)

Version assumptions in `toolchain.json` and provider constraints must be reconciled with the live
Coder version and downloaded provider schema. Registry module syntax is intentionally not embedded
until authoritative documentation can be accessed; IDEs initially use supported desktop Coder/SSH
access rather than speculative module declarations.
