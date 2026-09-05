# Operator runbook

## Read-only preflight

```bash
coder version
coder provisionerd list
coder templates list
docker info
terraform -chdir=template init -backend=false
terraform -chdir=template validate
```

Confirm version/provider compatibility, registry and routed vLLM access, GitHub external auth, secret scope, and an approved disposable namespace. Reconcile Bibliophilarr toolchain before building.

For CoderOps discovery and diagnostics, run:

```bash
./coderops/scripts/coderops-doctor
cd coderops/mcp && npm run inventory -- --json
cd coderops/mcp && npm run capabilities -- --json
```

## Build, scan, and authorized test deployment

```bash
# 0.2.6 is the current final workspace image (see toolchain.json). Replace
# :0.2.6 with the pinned manifest digest for an immutable rollout.
docker build -f image/Dockerfile -t REGISTRY/bibliophilarr-agent-workspace:0.2.6 .
docker run --rm REGISTRY/bibliophilarr-agent-workspace:0.2.6 image-self-test.sh
syft REGISTRY/bibliophilarr-agent-workspace:0.2.6 -o spdx-json >sbom.spdx.json
trivy image --exit-code 1 REGISTRY/bibliophilarr-agent-workspace:0.2.6
docker push REGISTRY/bibliophilarr-agent-workspace:0.2.6
# Push a new template version targeting the EXISTING Bibliophilarr template
# (positional name, --name = version name). `workspace_image` is a first-class
# coder_parameter, so its default (0.2.6) follows the active template version.
coder templates push -d template Bibliophilarr --name vX.Y
```

The last command requires explicit authorization. Record the digest and pin it. Test development plus exact-SHA validator workspaces, stop/restart persistence, all IDEs, clean independent validation, deletion/recreation, and secret-free evidence. Capture cold/warm/clone/restore/readiness/model timings. A future orchestrator interface may accept `{repository,ref,mode}` and return `{workspace_id,candidate_sha,results,evidence_uri}`; lifecycle APIs are intentionally absent.

When investigating drift or policy issues, prefer CoderOps inventory and capability output before changing the template or restarting workspaces.
