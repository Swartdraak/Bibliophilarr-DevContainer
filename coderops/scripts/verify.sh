#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root/mcp"
npm run build
npm test
echo "coderops verify: PASS"