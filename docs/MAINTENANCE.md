# Image, template, cache, and supply-chain maintenance

## Immutable release

1. Reconcile repository manifests and `toolchain.json`; choose a new semantic version.
2. Build with BuildKit; run image self-test and representative repository restore/build/frontend/test commands.
3. Generate an SBOM with Syft, scan with Trivy, and resolve policy failures.
4. Push a version tag, record its digest, optionally sign with Cosign, and update the template to the digest. Never overwrite a semantic tag.
5. Create two fresh workspaces with identical parameters and compare OS, tools, digest, SHA, commands, and results; then run IDE and independent-validator acceptance.

Monthly maintenance covers CVEs and tool updates; critical CVEs trigger a new image. Changes to application manifests, build/test/compose scripts, test stack, or agent/MCP requirements trigger compatibility review.

Changes to CoderOps canonical agents, skills, instructions, schemas, or MCP tools must also regenerate the adapter surfaces via `coderops/scripts/generate-adapters.sh` and re-run the CoderOps package tests.

## Cache reset and CI

Stop the workspace and remove only its named NuGet/Yarn volumes; never delete the home worktree as a cache operation. Container layers stay in the disposable sidecar. CI runs Terraform format/validate, ShellCheck, JSON and checkout tests, image build/self-test, SBOM, and scan. Protected integration CI exercises disposable Coder lifecycle. Devcontainer syntax checks are lightweight per-PR; full build/test is scheduled/manual.

## Rollback

Select the previous immutable template/image digest for new workspaces. Never mutate the bad tag. Preserve human worktree volumes, recreate disposable workspaces, and revalidate. Rollback does not bypass application governance.
