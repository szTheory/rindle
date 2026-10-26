#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
started=$SECONDS
for suite in exact_head_readiness exact_head_qualification readiness_runs readiness_remote exact_head_closure readiness_retention readiness_adoption readiness_acceptance readiness_snapshot; do
  bash "scripts/ci/test_${suite}.sh"
done
elapsed=$((SECONDS-started))
test "$elapsed" -lt 240
printf 'PASS: all cheap readiness fixtures in %ss (240s fixture budget within existing 5-minute CI seam)\n' "$elapsed"
