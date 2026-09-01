#!/usr/bin/env bash
set -euo pipefail
repo=${1:-/workspaces/Bibliophilarr}; cd "$repo"
[[ -z $(git status --porcelain) ]] || { echo 'candidate worktree is dirty' >&2; exit 40; }
echo "candidate=$(git rev-parse HEAD)"
if [[ -x ./build.sh ]]; then ./build.sh; else dotnet restore && dotnet build --no-restore; fi
if [[ -x ./test.sh ]]; then ./test.sh; else dotnet test --no-build; fi
