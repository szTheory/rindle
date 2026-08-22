#!/usr/bin/env bash
# SAFE-01: behavior-preservation contracts required before maintenance refactors.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

exec mix test --include contract --seed 0 \
  test/rindle/api_surface_boundary_test.exs \
  test/rindle/schema_prefix_contract_test.exs \
  test/rindle/migration_fast_test.exs \
  test/rindle/contracts/telemetry_contract_test.exs \
  test/rindle/error_test.exs \
  test/rindle/error_streaming_freeze_test.exs \
  test/install_smoke/ci_lane_split_test.exs \
  test/install_smoke/release_guard_meta_test.exs
