#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
terraform -chdir="$root/template" fmt -check -recursive
terraform -chdir="$root/template" init -backend=false
terraform -chdir="$root/template" validate
find "$root/scripts" "$root/image/scripts" "$root/workspace/bin" "$root/tests" -type f -print0 | xargs -0 shellcheck
python3 -m json.tool "$root/toolchain.json" >/dev/null
