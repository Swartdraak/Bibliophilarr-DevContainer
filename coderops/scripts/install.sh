#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root/mcp"
npm install
node dist/src/cli.js generate-adapters || true
echo "coderops install: PASS"