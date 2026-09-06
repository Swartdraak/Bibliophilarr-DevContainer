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

## Startup-health remediation validation flow (v2.8)

Use this flow when validating candidate startup-health fixes so false positives are not misclassified as hard failures:

```bash
# 1) Validate source before push
./scripts/validate-template.sh

# 2) Push candidate version (inactive)
./scripts/publish-coder-template.sh push --name v2.8

# 3) Create clean disposable workspace from candidate with bounded startup checks
./scripts/publish-coder-template.sh create-ws \
	--version v2.8 \
	--ws validation-v2-8 \
	--startup-smoke-checks true

# 4) Inspect startup and smoke logs via the workspace logs app or directly
coder ssh <user>/validation-v2-8 -- "tail -n 200 ~/.local/state/bibliophilarr/startup.log"
coder ssh <user>/validation-v2-8 -- "tail -n 200 ~/.local/state/bibliophilarr/smoke-checks.log"
```

Validation expectations for the remediation:
- startup finishes with explicit success/failure markers (`workspace startup: SUCCESS` or `FAILED`)
- checkout/startup/smoke operations are timeout-bounded and non-interactive
- smoke checks do not block login and still emit traceable evidence artifacts
- v2.8 clean-workspace validation shows no startup-health false-positive
