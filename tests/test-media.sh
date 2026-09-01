#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd); tmp=$(mktemp -d); scratch="/workspaces/media-test-$$/.workspace-test-media"
trap 'rm -rf "$tmp" "/workspaces/media-test-$$"' EXIT
mkdir -p "$tmp/source-a" "$tmp/source-e" "$scratch"
printf source >"$tmp/source-a/book.m4b"; printf ebook >"$tmp/source-e/book.epub"
export MEDIA_AUDIOBOOKS_SOURCE=$tmp/source-a MEDIA_EBOOKS_SOURCE=$tmp/source-e TEST_MEDIA_ROOT=$scratch
"$root/workspace/bin/seed-audiobook-fixture" book.m4b; "$root/workspace/bin/seed-ebook-fixture" book.epub
if "$root/workspace/bin/seed-audiobook-fixture" ../source-e/book.epub 2>/dev/null; then exit 1; fi
cmp "$tmp/source-a/book.m4b" "$TEST_MEDIA_ROOT/audiobooks/fixture-audiobook"
[[ $(stat -c %a "$TEST_MEDIA_ROOT/audiobooks/fixture-audiobook") == 600 ]]
"$root/workspace/bin/reset-test-media"
[[ -f $tmp/source-a/book.m4b && ! -e $TEST_MEDIA_ROOT/audiobooks/fixture-audiobook ]]
if TEST_MEDIA_ROOT=/tmp "$root/workspace/bin/reset-test-media" 2>/dev/null; then exit 1; fi
echo 'media safety tests: PASS'
