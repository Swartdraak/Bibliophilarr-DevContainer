#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp/origin.git"; git init -q "$tmp/source"
git -C "$tmp/source" config user.email test@example.invalid; git -C "$tmp/source" config user.name test
echo one >"$tmp/source/file"; git -C "$tmp/source" add file; git -C "$tmp/source" commit -qm first
git -C "$tmp/source" branch -M develop; git -C "$tmp/source" remote add origin "$tmp/origin.git"; git -C "$tmp/source" push -qu origin develop
git clone -q "$tmp/origin.git" "$tmp/work" --branch develop
sha=$(git -C "$tmp/work" rev-parse HEAD); "$root/scripts/checkout-ref.sh" "$tmp/work" "$sha" validator
[[ $(git -C "$tmp/work" rev-parse HEAD) == "$sha" ]]; [[ -z $(git -C "$tmp/work" symbolic-ref -q HEAD) ]]
if "$root/scripts/checkout-ref.sh" "$tmp/work" nonexistent validator 2>/dev/null; then echo "expected checkout-ref to fail on nonexistent ref" >&2; exit 1; fi
echo dirty >>"$tmp/work/file"; "$root/scripts/checkout-ref.sh" "$tmp/work" develop development
rg -q dirty "$tmp/work/file"; echo 'checkout tests: PASS'
