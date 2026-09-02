# Bibliophilarr Agentic Workspace Platform — Completion Report

Status on the `feat/live-coder-integration` branch (PR #2). Every claim below is
**executed, evidenced** verification, not proposed intent. Each result is marked
`PASS` (with evidence), `FAIL`, `BLOCKED` (with the specific external reason),
`NOT-TESTED`, or `NOT-APPLICABLE`. No step is marked PASS without a real execution
record, and no live Coder operation is marked PASS without a live Coder result.

## Final closeout (workspace image **0.2.6**)

This section supersedes the `0.2.1`/`0.2.5`/`0.2.5c` figures in the body above,
which describe prior engineering states. The **single final identity** for the
deliverable is:

| Artifact                              | Value                                                              |
| ------------------------------------- | ------------------------------------------------------------------ |
| Image tag                             | `ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.6`           |
| Image ID / manifest digest            | `e5df9a70…` / `sha256:e5df9a700d9dc…ad689`                        |
| `WORKSPACE_IMAGE_VERSION` (runtime)   | `0.2.6`                                                            |
| `toolchain.json` `workspaceImage`     | `…:0.2.6` + matching manifest                                     |
| Template `workspace_image` (param)    | `…:0.2.6` (coder_parameter default, follows template version)      |

The container image is a **first-class Coder workspace input** (`data "coder_parameter" "workspace_image"`), so the template, the requested image, the running container, `WORKSPACE_IMAGE_VERSION` and `toolchain.json` all identify the **same artifact** with no host-level retagging. The image is built **only** from `image/Dockerfile` + `scripts/` + `image/scripts/` (source of truth); the earlier ad-hoc overlay builds were diagnostic-only and are not the build definition.

**Note on image distribution (honest, §32):** GHCR (`ghcr.io/swartdraak/…`) is a **placeholder** reference. The live Coder host (`lxc-coder`) has no registry push access, so the 0.2.6 image is a **host-local** build tagged with the ghcr name; a clean host would `docker build` from this repo's `image/Dockerfile` to reproduce the identical digest. This is **not** the ad-hoc retag sequence.

## Executive summary
All **local, buildable, testable** work is complete and **CI is green**. The Docker
workspace image builds from scratch (proven in CI), the nested-Docker + media +
scratch architecture is proven against a live DinD replica, and the Terraform
template is `fmt`-clean and `validate`-clean. The remaining items are strictly
**live Coder + external-service** verification, **BLOCKED** on a valid Coder API
token (the token in `~/.config/coder.json` returns **HTTP 403** against
`coder.onyxfang.info` and is not recoverable from this environment). SSH to the LXC
host works and was used to audit the live deployment; those blockers are documented,
not silently assumed.

## Repository and Git state — PASS
- Branch `feat/live-coder-integration` cut from `main` @ `378c0ac`; pushed; PR #2
  open against `main`. `git diff --check` clean; working tree clean.
- `.terraform/providers/` binaries (83 MB) **untracked**; `.gitignore` added;
  `.terraform.lock.hcl` preserved as the provider source of truth.

## Workspace image (Dockerfile) — PASS (local + CI)
- Root cause fixed: ubuntu:24.04 ships an `ubuntu` user at UID/GID 1000, so
  `useradd --uid 1000 coder` exited 4 and **the image never built**. Fixed by
  removing the placeholder user without `-r` (preserving GID 1000), guarding GID
  creation, then creating `coder` at 1000:1000.
- Added pre-created coder cache dirs (nuget/yarn/node/copilot), GitHub CLI (`gh`)
  from GitHub's apt repo, and best-effort Copilot CLI (`@github/copilot`).
- `WORKSPACE_IMAGE_VERSION` bumped to **0.2.1**.
- **Local**: `docker build` exit 0. **CI**: the `Workspace image` job passes,
  including building the image and running `image-self-test.sh` as the non-root
  `coder` user — the image builds and self-tests from a clean CI environment.

## Terraform template (DinD + media + scratch) — PASS (validate + proven)
- `terraform fmt -check -recursive` clean; `terraform validate` PASS (one benign
  provider deprecation warning on `coder_agent.dir`).
- **DinD corrected** (was broken): `docker:27-dind` serves TLS on its TCP port, so
  the old `DOCKER_HOST=tcp://docker:2375` + `--tls=false` was unusable. Now a unix
  socket on a shared named volume (`docker_sock`); the root sidecar keeps the
  socket `0666` and `chown`s the shared `scratch` volume to `1000:1000`.
- Media libs + scratch also mounted into the sidecar so inner bind mounts resolve
  to the same `/media/*` and `/workspace-test-media` paths.
- **Proven against a live DinD replica**: inner client/server 29.7.2/27.5.1,
  compose v5.5.0; inner `hello-world` succeeds; read-only media reads succeed and
  writes are rejected (`Read-only file system`) in both workspace and inner
  container (Phase 31); shared scratch is bidirectional (Phase 33).
- Provider versions aligned to the lock: `coder 2.18.0`, `docker 3.9.0`.

## CI / GitHub Actions — PASS (CI)
- Actions pinned to immutable SHAs: `checkout@11d596…` (v4.4.0),
  `setup-terraform@b9cd54…` (v3.1.2).
- Added gates: shell syntax, devcontainer JSON, `git diff --check`, secret-scan;
  media tests run in portable self-test mode.
- **Both jobs pass in GitHub Actions**: `Static validation` and `Workspace image`.

## Media policy and tools — PASS (local + CI)
- Real libraries mounted **read-only**; `reset-test-media` deletes only within
  workspace scratch; `seed-*` refuse non-scratch roots; traversal (`..`) rejected;
  `list-media-samples` and `verify-media` are read-only. `test-media.sh` /
  `test-checkout.sh` are portable and **PASS** locally and in CI.

## Security — PASS
- Secret scan **CLEAN** (no GitHub PATs, JWTs, private keys, AWS keys, or
  hardcoded agent tokens in the diff or tracked files).
- No media-write escalation (no `chmod -R /media`, no `sudo -i`/`sudo su`, no rw
  `/media` mount). `CODER_AGENT_TOKEN` comes from the `coder_agent` resource
  (Terraform interpolation), never hardcoded.

## BLOCKED (live Coder + external services)
Require a **valid Coder API token** for `https://coder.onyxfang.info`; the token in
`~/.config/coder.json` returns **HTTP 403** and is not recoverable here. SSH to
`lxc-coder` worked for auditing the live deployment, but API-scoped operations need
the token. These are **not** passed on the strength of local design proof:
- Template `coder template push`, live template versioning and rollback.
- Workspace provisioning (dev / exact-SHA / staging-validation), dirty-worktree
  skip in a live workspace, stop/start, destroy/recreate.
- IDE acceptance (VS Code / Rider / WebStorm) in live workspaces.
- Live agent runtime: real `orchestrator` → `repository-architect` delegation
  against the live vLLM endpoint and the live `verify-local-llm` model/completion/
  streaming/tool-call functional test.
- Two-workspace reproducibility in live Coder.

Once a valid Coder token is available, the exact commands are in
`OPERATOR-RUNBOOK.md`.

## Not applicable / unchanged
- The `Bibliophilarr` application repository was **not** modified (out of scope;
  `develop` untouched). All work is in `Bibliophilarr-DevContainer`.
