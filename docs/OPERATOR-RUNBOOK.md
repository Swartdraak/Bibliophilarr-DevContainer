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

## Build, scan, and authorized test deployment

```bash
docker build -f image/Dockerfile -t REGISTRY/bibliophilarr-agent-workspace:0.2.1 .
docker run --rm REGISTRY/bibliophilarr-agent-workspace:0.2.1 image-self-test.sh
syft REGISTRY/bibliophilarr-agent-workspace:0.2.1 -o spdx-json >sbom.spdx.json
trivy image --exit-code 1 REGISTRY/bibliophilarr-agent-workspace:0.2.1
docker push REGISTRY/bibliophilarr-agent-workspace:0.2.1
coder templates push bibliophilarr-agent-workspace-test -d template
```

The last command requires explicit authorization. Record the digest and pin it. Test development plus exact-SHA validator workspaces, stop/restart persistence, all IDEs, clean independent validation, deletion/recreation, and secret-free evidence. Capture cold/warm/clone/restore/readiness/model timings. A future orchestrator interface may accept `{repository,ref,mode}` and return `{workspace_id,candidate_sha,results,evidence_uri}`; lifecycle APIs are intentionally absent.
