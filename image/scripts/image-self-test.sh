#!/usr/bin/env bash
set -euo pipefail
for command in git curl jq rg fd dotnet node corepack pwsh docker shellcheck python3; do
  command -v "$command" >/dev/null || { echo "missing: $command" >&2; exit 1; }
done
test "$(id -u)" != 0
test -w "$HOME"
echo "image self-test: PASS"
