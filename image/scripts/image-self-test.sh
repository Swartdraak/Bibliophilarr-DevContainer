#!/usr/bin/env bash
set -euo pipefail
# Proven base toolchain (regression guard - do not remove).
for command in git curl jq rg fd dotnet node corepack pwsh docker shellcheck python3; do
  command -v "$command" >/dev/null || { echo "missing: $command" >&2; exit 1; }
done
# Docker Compose (via plugin) is the documented container-validation path.
docker compose version >/dev/null 2>&1 || { echo "missing: docker compose" >&2; exit 1; }
# GitHub CLI is required by verify-workspace.sh / the repository agent workflows.
command -v gh >/dev/null || { echo "missing: gh" >&2; exit 1; }
# §15 Copilot CLI (agentic against the local vLLM endpoint) must be present.
command -v copilot >/dev/null || { echo "missing: copilot" >&2; exit 1; }
# §13/§15 Codex CLI must be present (new in 0.2.4).
command -v codex >/dev/null || { echo "missing: codex" >&2; exit 1; }

test "$(id -u)" != 0
test -w "$HOME"

# §20 media-common regression: the sourced function library must provide
# initialize_test_media (the workspace-startup.sh fix relied on a `source`,
# because media-common is a library, not an executable). Verify it is sourceable
# and the entrypoint is defined without executing any mutation.
if [[ -r /opt/workspace/bin/media-common ]]; then
  # shellcheck source=/dev/null # runtime path; not present in the repo tree
  source /opt/workspace/bin/media-common
  declare -F initialize_test_media >/dev/null \
    || { echo "media-common: initialize_test_media not defined" >&2; exit 1; }
else
  echo "media-common: /opt/workspace/bin/media-common not readable" >&2; exit 1
fi

# §19/§30 image version must be the final clean artifact (0.2.8 adds the headless
# `assign-task` helper + the Rider NuGet ownership startup fix; 0.2.7 added .NET 10).
test "${WORKSPACE_IMAGE_VERSION:-}" = "0.2.8" \
  || { echo "WORKSPACE_IMAGE_VERSION=${WORKSPACE_IMAGE_VERSION:-unset} (expected 0.2.8)" >&2; exit 1; }

# .NET SDK provisioning: global.json requires the 10.0 SDK (e.g. 10.0.400) and
# the project still uses a 8.0 target/runtime, so BOTH must be installed. A
# missing 10.0 SDK means `dotnet test` cannot run the .NET 10 targets -> fail.
dotnet --list-sdks >/tmp/dotnet-sdks 2>&1 || { echo "dotnet --list-sdks failed" >&2; exit 1; }
grep -Eq '^10\.0\.[0-9]+' /tmp/dotnet-sdks \
  || { echo ".NET 10 SDK missing from: $(tr '\n' ' ' </tmp/dotnet-sdks)" >&2; exit 1; }
grep -Eq '^8\.0\.[0-9]+' /tmp/dotnet-sdks \
  || { echo ".NET 8 SDK missing from: $(tr '\n' ' ' </tmp/dotnet-sdks)" >&2; exit 1; }
rm -f /tmp/dotnet-sdks

# §29-A regression: the Coder command must NOT be swallowed. The image ENTRYPOINT
# is empty ([]) and a fallback CMD exists. We cannot read the image's ENTRYPOINT
# from inside, so this guard asserts the startup contract that the container is
# NOT running its own keep-alive as PID 1 under a non-empty entrypoint. In a Coder
# workspace the agent is the process tree; this check is informational here and the
# authoritative ENTRYPOINT regression is tests/ (image-build level).
echo "ENTRYPOINT contract: Coder injects the command; image ships ENTRYPOINT [] (no keep-alive swallow)"

# §27/§22 checkout-ref.sh regression: the fresh-clone guard must be present
# (an unpopulated --no-checkout clone must be force-checked-out, not skipped as
# "dirty"). Guard against regression of the 2026-09-02 fix.
grep -q 'index_entry_count' /opt/workspace/bin/checkout-ref.sh \
  || { echo "checkout-ref.sh: fresh-clone guard (index_entry_count) missing" >&2; exit 1; }

# §29-D regression (code-server home/cache ownership): the coder user (UID 1000)
# must be able to create the exact dirs code-server's install uses. This is the
# definitive check for the "mkdir ~/.cache/code-server: Permission denied" bug.
if [[ "$(id -u)" -eq 1000 ]]; then
  if ! mkdir -p /home/coder/.cache/code-server /home/coder/.config/gh \
    || ! touch /home/coder/.cache/code-server/.selftest; then
    echo "home/cache: coder (uid 1000) cannot write ~/.cache/code-server" >&2; exit 1
  fi
  rm -f /home/coder/.cache/code-server/.selftest
fi

# §29-E regression (media-common sourcing): initialize_test_media must be defined
# after sourcing. Guards against "initialize_test_media: command not found".
# shellcheck source=/dev/null # runtime path; not present in the repo tree
if ! source /opt/workspace/bin/media-common 2>/dev/null || ! declare -f initialize_test_media >/dev/null 2>&1; then
  echo "media-common: initialize_test_media not defined after sourcing" >&2; exit 1
fi

echo "image self-test: PASS (v${WORKSPACE_IMAGE_VERSION})"
