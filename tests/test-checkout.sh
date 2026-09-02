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
# grep (not rg) so the test runs on minimal runners without ripgrep preinstalled.
grep -q dirty "$tmp/work/file"

# §29-B regression: a fresh `git clone --no-checkout` (index empty, ~N "D"
# deletions in status) must be POPULATED by checkout-ref, NOT skipped as "dirty
# developer work". This is the 2026-09-02 bug that left the workspace on an empty
# tree on `main` instead of the requested ref. Guard against reintroduction.
git -C "$tmp/work" rm -rq --ignore-unmatch . >/dev/null 2>&1 || true
git clone -q --no-checkout "$tmp/origin.git" "$tmp/fresh"
git -C "$tmp/fresh" checkout -q develop || true
# Force the pristine --no-checkout state: unpopulate but keep the develop HEAD.
git -C "$tmp/fresh" rm -rq --ignore-unmatch . >/dev/null 2>&1 || true
# The checkout must detect the empty index and pull the files back for develop.
"$root/scripts/checkout-ref.sh" "$tmp/fresh" develop development
populated_after=$(git -C "$tmp/fresh" ls-files | wc -l)
[[ "$populated_after" -gt 0 ]] || { echo "fresh --no-checkout clone not populated (index-entry regression)" >&2; exit 1; }
[[ $(git -C "$tmp/fresh" rev-parse --abbrev-ref HEAD) == "develop" ]] || { echo "fresh --no-checkout clone not on develop" >&2; exit 1; }
[[ -z $(git -C "$tmp/fresh" status --porcelain) ]] || { echo "fresh --no-checkout clone left dirty" >&2; exit 1; }

echo 'checkout tests: PASS'
