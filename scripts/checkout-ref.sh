#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}; requested=${2:?git ref required}; mode=${3:-development}
cd "$repo"
if [[ -n $(git status --porcelain) ]]; then
  if [[ $mode == validator || $mode == release-validation ]]; then
    echo "validator repository is unexpectedly dirty" >&2; exit 20
  fi
  echo "NOTICE: existing worktree is dirty; checkout skipped to protect work" >&2; exit 0
fi
git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*'
if [[ $requested =~ ^[0-9a-fA-F]{40}$ ]]; then
  git cat-file -e "${requested}^{commit}" 2>/dev/null || git fetch origin "$requested"
  git cat-file -e "${requested}^{commit}" 2>/dev/null || { echo "requested SHA does not exist" >&2; exit 21; }
  git checkout --detach "$requested"
  [[ $(git rev-parse HEAD) == "${requested,,}" ]] || { echo "HEAD verification failed" >&2; exit 22; }
elif git show-ref --verify --quiet "refs/remotes/origin/$requested"; then
  git checkout -B "$requested" "origin/$requested"
elif git show-ref --verify --quiet "refs/tags/$requested"; then
  git checkout --detach "refs/tags/$requested"
else
  echo "requested ref '$requested' does not exist; refusing fallback" >&2; exit 23
fi
printf 'checked out %s at %s\n' "$requested" "$(git rev-parse HEAD)"
