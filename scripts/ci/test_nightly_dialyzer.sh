#!/usr/bin/env bash
# Deterministic regression matrix for the supported Nightly Dialyzer runner.
# shellcheck disable=SC2016 # GitHub expressions are asserted as literal text.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runner="${repo_root}/scripts/ci/run_nightly_dialyzer.sh"
fingerprint="${repo_root}/.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json"
setup_action="${repo_root}/.github/actions/setup-elixir/action.yml"
nightly_workflow="${repo_root}/.github/workflows/nightly.yml"

pass=0
fail=0

fail_case() {
  echo "FAIL — $1" >&2
  fail=$((fail + 1))
}

pass_case() {
  echo "ok   — $1"
  pass=$((pass + 1))
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass_case "$name"
  else
    fail_case "${name}: missing ${needle}"
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail_case "${name}: prohibited ${needle}"
  else
    pass_case "$name"
  fi
}

assert_count() {
  local name="$1" file="$2" needle="$3" expected="$4" actual
  actual="$(grep -Fc -- "$needle" "$file" || true)"
  if [ "$actual" -eq "$expected" ]; then
    pass_case "$name"
  else
    fail_case "${name}: expected ${expected} occurrences of ${needle}, got ${actual}"
  fi
}

assert_order() {
  local name="$1" file="$2" first="$3" second="$4" first_line second_line
  first_line="$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1 || true)"
  second_line="$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1 || true)"
  if [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ]; then
    pass_case "$name"
  else
    fail_case "${name}: expected ${first} before ${second}"
  fi
}

assert_case() {
  local name="$1" mode="$2" scenario="$3" expected_status="$4" expected_commands="$5"
  local case_root fake_mix command_log dialyzer_log output status=0 commands

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/rindle-dialyzer-test.XXXXXX")"
  fake_mix="${case_root}/mix"
  command_log="${case_root}/commands.log"
  dialyzer_log="${case_root}/dialyzer.log"

  cp "${repo_root}/scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh" "$fake_mix"
  chmod +x "$fake_mix"
  mkdir -p "${case_root}/plts"
  printf 'restored fixture\n' > "${case_root}/plts/dialyzer.plt"

  output="$(
    MIX_BIN="$fake_mix" \
      PLT_DIR="${case_root}/plts" \
      DIALYZER_LOG="$dialyzer_log" \
      RINDLE_DIALYZER_TEST_SCENARIO="$scenario" \
      RINDLE_DIALYZER_COMMAND_LOG="$command_log" \
      bash "$runner" "$mode" 2>&1
  )" || status=$?

  commands="$(tr '\n' '|' < "$command_log" 2>/dev/null || true)"
  if [ "$status" -ne "$expected_status" ]; then
    fail_case "${name}: expected exit ${expected_status}, got ${status}; output=${output}"
  elif [ "$commands" != "$expected_commands" ]; then
    fail_case "${name}: expected commands ${expected_commands}, got ${commands}"
  else
    pass_case "$name"
  fi

  rm -rf "$case_root"
}

assert_case "fresh builds then analyzes once" fresh success 0 "dialyzer --plt|dialyzer --format github|"
assert_case "valid restored PLT analyzes once" restored success 0 "dialyzer --format github|"
assert_case "old restored PLT rebuilds and re-analyzes once" restored stale_then_success 0 "dialyzer --format github|dialyzer --plt|dialyzer --format github|"
assert_case "missing restored PLT stays red without rebuild" restored missing 12 "dialyzer --format github|"
assert_case "corrupt restored PLT stays red without rebuild" restored corrupt 13 "dialyzer --format github|"
assert_case "fresh PLT build failure stays red" fresh build_failure 14 "dialyzer --plt|"
assert_case "genuine warning stays red without rebuild" restored genuine_warning 15 "dialyzer --format github|"
assert_case "unknown analysis failure stays red without rebuild" restored unknown_failure 16 "dialyzer --format github|"
assert_case "failed stale rebuild stays red without re-analysis" restored stale_build_failure 14 "dialyzer --format github|dialyzer --plt|"
assert_case "failed post-rebuild analysis stays red without another retry" restored stale_reanalysis_failure 17 "dialyzer --format github|dialyzer --plt|dialyzer --format github|"

if jq -e '
  .schema_version == 1 and
  .repository == "szTheory/rindle" and
  .failed_source_sha == "45ebde5e1bb851eb6e8a943ef68c52a714684661" and
  .success_run.id == 33482708198 and .success_run.number == 93 and
  .failure_run.id == 34324448817 and .failure_run.number == 101 and
  .cache_key.success_primary == .cache_key.failure_primary and
  .resolved_toolchains.success.otp == "OTP-27.3.4.16" and
  .resolved_toolchains.failure.otp == "OTP-27.3.4.17" and
  .failure_fingerprint.exact_marker == "Old PLT file"
' "$fingerprint" >/dev/null; then
  pass_case "bounded #93/#101 failure fingerprint is complete"
else
  fail_case "bounded #93/#101 failure fingerprint is incomplete"
fi

assert_contains "composite exposes resolved Elixir output" "$setup_action" "resolved-elixir-version:"
assert_contains "composite forwards exact installed Elixir" "$setup_action" 'value: ${{ steps.beam.outputs.elixir-version }}'
assert_contains "composite exposes resolved OTP output" "$setup_action" "resolved-otp-version:"
assert_contains "composite forwards exact installed OTP" "$setup_action" 'value: ${{ steps.beam.outputs.otp-version }}'
assert_count "Nightly invokes fresh mode exactly once" "$nightly_workflow" "run_nightly_dialyzer.sh fresh" 1
assert_count "Nightly invokes restored mode exactly once" "$nightly_workflow" "run_nightly_dialyzer.sh restored" 1
assert_contains "PLT key uses resolved Elixir patch" "$nightly_workflow" 'elixir${{ steps.setup.outputs.resolved-elixir-version }}'
assert_contains "PLT key uses resolved OTP patch" "$nightly_workflow" 'otp${{ steps.setup.outputs.resolved-otp-version }}'
assert_contains "PLT key retains input hashes" "$nightly_workflow" "hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs')"
assert_not_contains "PLT key rejects requested-only identity" "$nightly_workflow" "otp27-elixir1.17"
assert_not_contains "PLT restore has no cross-toolchain fallback" "$nightly_workflow" "restore-keys:"
assert_order "fresh evidence precedes cache save" "$nightly_workflow" "run_nightly_dialyzer.sh fresh" "- name: Save PLT cache"
assert_order "exact restore precedes restored evidence" "$nightly_workflow" "- name: Restore exact PLT cache" "run_nightly_dialyzer.sh restored"

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "$pass" -gt 0 ] && [ "$fail" -eq 0 ]
