# Bibliophilarr Coder Agentic Workspace

Standalone, source-controlled Coder template and canonical workspace-image project for
`Swartdraak/Bibliophilarr`. It also includes a CoderOps control layer under `coderops/`
for discovery, drift detection, policy, audit logging, and safe operational planning.
It does **not** alter the application repository or a live Coder deployment. The current
handoff status is **READY FOR CODER TEST DEPLOYMENT**, not production-ready.

## Quick checks

```bash
./tests/test-checkout.sh
./scripts/validate-template.sh       # requires Terraform/provider network access
docker build -f image/Dockerfile -t bibliophilarr-agent-workspace:0.2.1 .
docker run --rm bibliophilarr-agent-workspace:0.2.1 image-self-test.sh
```

Start with [the final design report](docs/FINAL-DESIGN-REPORT.md), then follow the
[operator runbook](docs/OPERATOR-RUNBOOK.md). Image and template publication are deliberately
separate, human-gated operations.

For CoderOps-specific operation and architecture details, see `coderops/README.md` and
`coderops/docs/IMPLEMENTATION-REPORT.md`.

## Package map

* `image/`: the one multi-IDE execution environment.
* `template/`: Docker-runtime Coder provisioning; no live deployment automation.
* `scripts/`: ref-safe bootstrap, inventory, model and candidate validation.
* `.devcontainer/`: thin local adapter over the same canonical image.
* `workspace/bin/`: agent-runtime and privacy-safe media utilities.
* `coderops/`: canonical CoderOps policy, runtime, schemas, agents, skills, instructions, and adapters.
* `docs/`: architecture, security, integrations, maintenance and acceptance evidence.
