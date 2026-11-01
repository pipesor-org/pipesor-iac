#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
message=$(mktemp)
trap 'rm -f "$message"' EXIT HUP INT TERM

for type in build chore ci docs feat fix perf refactor revert style test; do
  printf '%s: explain setup\n' "$type" > "$message"
  lefthook run commit-msg -- "$message"
done

printf 'feat(ui): add navigation\n\nOptional body\n' > "$message"
lefthook run commit-msg -- "$message"

printf 'feat(api): replace endpoint\n\nBREAKING CHANGE: use the new endpoint\n' > "$message"
lefthook run commit-msg -- "$message"

printf 'feat(api)!: replace endpoint\n' > "$message"
lefthook run commit-msg -- "$message"

pr_title='feat(api): replace endpoint'
pr_body='BREAKING CHANGE: use the new endpoint'
printf '%s\n' "$pr_title" | bun run commitlint
printf '%s\n\n%s\n' "$pr_title" "$pr_body" | bun run commitlint
if printf '%s\n' 'update infrastructure' | bun run commitlint >/dev/null 2>&1; then
  printf '%s\n' 'Unexpectedly accepted a nonconventional PR title' >&2
  exit 1
fi

padding=$(printf '%067d' 0 | tr '0' 'a')
printf 'docs: %s\n' "${padding%?}" > "$message"
lefthook run commit-msg -- "$message"

for subject in \
  'update docs' \
  'unknown: explain setup' \
  'Fix: handle input' \
  'fix: ' \
  'fix: Handle input' \
  'fix: handle Input' \
  'fix: handle input.' \
  "Merge branch 'main'" \
  'Merge pull request #1 from pipesor-org/feature/example' \
  'v1.2.3' \
  "docs: $padding"; do
  printf '%s\n' "$subject" > "$message"
  if lefthook run commit-msg -- "$message" >/dev/null 2>&1; then
    printf 'Unexpectedly accepted: %s\n' "$subject" >&2
    exit 1
  fi
done

printf '%s\n' 'Commit-message checks passed.'
