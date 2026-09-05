#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cp -f "$root/coderops.example.yaml" "${CODEROPS_CONFIG:-$root/coderops.example.yaml}"
echo "coderops configure: example configuration available at $root/coderops.example.yaml"