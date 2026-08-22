#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
baseline_path="${CREDO_QUALITY_BASELINE:-$repo_root/scripts/maintainer/credo_complexity_baseline.json}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/rindle-credo-quality.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "[credo-quality] $*" >&2
  exit 1
}

normalize_issues() {
  mix run --no-start scripts/maintainer/credo_quality_normalize.exs issues
}

normalize_baseline() {
  mix run --no-start scripts/maintainer/credo_quality_normalize.exs baseline
}

[ -f "$baseline_path" ] || fail "baseline not found: $baseline_path"

cd "$repo_root"
mix credo suggest --config-name blocking_warnings --format oneline
mix credo suggest --config-name public_contract --format oneline

issues_json="$tmp_dir/complexity.json"
actual_json="$tmp_dir/actual.json"
expected_json="$tmp_dir/expected.json"

mix credo suggest --config-name complexity_inventory --format json --mute-exit-status > "$issues_json" ||
  fail "Credo complexity inventory failed"

normalize_issues < "$issues_json" > "$actual_json" ||
  fail "Credo emitted malformed complexity inventory JSON"
normalize_baseline < "$baseline_path" > "$expected_json" ||
  fail "complexity baseline is malformed"

cmp -s "$expected_json" "$actual_json" || {
  diff -u "$expected_json" "$actual_json" >&2 || true
  fail "complexity/nesting identity multiset differs from the reviewed baseline"
}

echo "[credo-quality] blocking warnings, public contract, and complexity inventory passed"
