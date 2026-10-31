#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
message=$(mktemp)
trap 'rm -f "$message"' EXIT HUP INT TERM

for type in build ci docs feat fix perf refactor revert style test; do
  printf '%s: explain setup\n' "$type" > "$message"
  "$root/.githooks/commit-msg" "$message"
done

printf 'feat(ui): add navigation\n\nOptional body\n' > "$message"
"$root/.githooks/commit-msg" "$message"

printf 'feat(api): replace endpoint\n\nBREAKING CHANGE: use the new endpoint\n' > "$message"
"$root/.githooks/commit-msg" "$message"

padding=$(printf '%067d' 0 | tr '0' 'a')
printf 'docs: %s\n' "${padding%?}" > "$message"
"$root/.githooks/commit-msg" "$message"

for subject in \
  'update docs' \
  'chore: update tooling' \
  'unknown: explain setup' \
  'Fix: handle input' \
  'fix: ' \
  'fix: Handle input' \
  'fix: handle Input' \
  'fix: handle input.' \
  'feat(api)!: replace endpoint' \
  "Merge branch 'main'" \
  'Merge pull request #1 from pipesor-org/feature/example' \
  'v1.2.3' \
  "docs: $padding"; do
  printf '%s\n' "$subject" > "$message"
  if "$root/.githooks/commit-msg" "$message" >/dev/null 2>&1; then
    printf 'Unexpectedly accepted: %s\n' "$subject" >&2
    exit 1
  fi
done

printf '%s\n' 'Commit-message checks passed.'
