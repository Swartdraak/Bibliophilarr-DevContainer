#!/usr/bin/env bash
set -euo pipefail
repo=${1:?repository path required}; requested=${2:?git ref required}; mode=${3:-development}
cd "$repo"
# Distinguish a FRESH/unpopulated clone from a populated dirty worktree.
# `git clone --no-checkout` leaves HEAD on the default branch with NO checked-out
# files: the index/worktree have no files, and `git status --porcelain` reports
# every tracked file as deleted (`D`). That is NOT a developer's uncommitted
# work - it is the normal state we must now populate by checking out the
# requested ref. Treating it as "dirty -> skip" silently leaves an empty tree on
# the wrong branch (BUG 2026-09-02: fresh E2E workspace checked `main` empty,
# request was `develop`).
#
# "Genuinely dirty" = the worktree is populated (has checked-out tracked files)
# AND has modifications (staged `A`/`M`, changes, or untracked `??` / new files).
# So: if there are NO staged/modified/untracked entries at all, the only possible
# status entries are deletions of files that were never checked out -> force
# checkout the requested ref.
# The primary, unambiguous "this was never checked out" signal is an EMPTY index:
# `git clone --no-checkout` leaves no index entries, so `git ls-files` returns
# nothing. A populated worktree (even a fully-deleted one) still has index
# entries. So: index-empty  =>  fresh unpopulated clone  =>  safe to force-checkout.
index_entry_count=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
if [[ "$index_entry_count" -eq 0 ]]; then
  # Fresh/unpopulated clone: populate it. Safe to hard-reset (nothing to lose).
  echo "NOTICE: populating unpopulated clone (fresh --no-checkout state); force-checking-out requested ref" >&2
  git reset --hard -q 2>/dev/null || true
else
  # Populated worktree: protect any real uncommitted work.
  porcelain=$(git status --porcelain 2>/dev/null || true)
  # "Real" changes: staged (col1 A/M/R/C; a col1 D here means the dev staged a
  #  deletion of a previously-checked-out file), worktree-modified (col2
  #  non-space), or untracked (? ). A bare unstaged worktree deletion (col2 D)
  #  on a populated repo IS dev work (they rm'd a tracked file) -> protect.
  if [[ -n "$porcelain" ]]; then
    if [[ $mode == validator || $mode == release-validation ]]; then
      echo "validator repository is unexpectedly dirty" >&2; exit 20
    fi
    echo "NOTICE: existing worktree has uncommitted work; checkout skipped to protect work" >&2; exit 0
  fi
  # Populated + clean: normal path (re)checks out the requested ref below.
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
