#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
preflight="$root/.planning/phases/139-exact-head-readiness-closure/139-preflight.sh"
missing="$(mktemp -d)"
trap 'rm -rf "$missing"' EXIT
if RINDLE_138_EVIDENCE_DIR="$missing" bash "$preflight" >"$missing/output" 2>&1; then
  echo 'FAIL: absent retained matrix was accepted' >&2
  exit 1
fi
grep -q 'retained Phase 138 inputs absent' "$missing/output" || {
  echo 'FAIL: missing-input rejection lacked a reason' >&2
  exit 1
}
real_git="$(command -v git)"
mkdir "$missing/bin"
printf '%s\n' '#!/bin/sh' 'if [ "$1" = diff ]; then exit 1; fi' 'exec "$RINDLE_139_REAL_GIT" "$@"' > "$missing/bin/git"
chmod +x "$missing/bin/git"
if RINDLE_139_REAL_GIT="$real_git" PATH="$missing/bin:$PATH" bash "$preflight" >"$missing/dirty-output" 2>&1; then
  echo 'FAIL: uncommitted upstream evidence was accepted' >&2
  exit 1
fi
grep -q 'differs from HEAD' "$missing/dirty-output" || {
  echo 'FAIL: dirty upstream rejection lacked a reason' >&2
  exit 1
}
bash "$preflight"
echo 'PASS: preflight rejects absent matrix and uncommitted upstream evidence; no-credit deferral intact'
