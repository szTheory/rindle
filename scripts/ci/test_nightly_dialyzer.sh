#!/usr/bin/env bash
# Deterministic regression matrix for the supported Nightly Dialyzer runner.
# shellcheck disable=SC2016 # GitHub expressions are asserted as literal text.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runner="${repo_root}/scripts/ci/run_nightly_dialyzer.sh"
fingerprint="${repo_root}/scripts/ci/fixtures/nightly_failure_fingerprint.json"
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
  local case_root repo_fixture fixture_runner fake_mix command_log dialyzer_log output status=0 commands

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/rindle-dialyzer-test.XXXXXX")"
  repo_fixture="${case_root}/repo"
  fixture_runner="${repo_fixture}/scripts/ci/run_nightly_dialyzer.sh"
  fake_mix="${case_root}/mix"
  command_log="${case_root}/commands.log"
  dialyzer_log="${case_root}/dialyzer.log"

  mkdir -p "${repo_fixture}/scripts/ci" "${repo_fixture}/priv/plts"
  cp "$runner" "$fixture_runner"
  cp "${repo_root}/scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh" "$fake_mix"
  chmod +x "$fake_mix" "$fixture_runner"
  printf 'restored fixture\n' > "${repo_fixture}/priv/plts/dialyzer.plt"

  output="$(
    MIX_BIN="$fake_mix" \
      DIALYZER_LOG="$dialyzer_log" \
      RINDLE_DIALYZER_TEST_SCENARIO="$scenario" \
      RINDLE_DIALYZER_COMMAND_LOG="$command_log" \
      bash "$fixture_runner" "$mode" 2>&1
  )" || status=$?

  if [ -f "$command_log" ]; then
    commands="$(tr '\n' '|' < "$command_log")"
  fi
  if [ "$status" -ne "$expected_status" ]; then
    fail_case "${name}: expected exit ${expected_status}, got ${status}; output=${output}"
  elif [ "$commands" != "$expected_commands" ]; then
    fail_case "${name}: expected commands ${expected_commands}, got ${commands}"
  else
    pass_case "$name"
  fi

  rm -rf "$case_root"
}

assert_approved_repo_reset() {
  local name="approved repository PLT child resets from an external caller directory"
  local case_root repo_fixture caller_dir fake_mix command_log dialyzer_log output status=0

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/rindle-dialyzer-approved.XXXXXX")"
  repo_fixture="${case_root}/repo"
  caller_dir="${case_root}/caller"
  fake_mix="${case_root}/mix"
  command_log="${case_root}/commands.log"
  dialyzer_log="${case_root}/dialyzer.log"

  mkdir -p "${repo_fixture}/scripts/ci" "${repo_fixture}/priv/plts" "${caller_dir}/priv/plts"
  cp "$runner" "${repo_fixture}/scripts/ci/run_nightly_dialyzer.sh"
  cp "${repo_root}/scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh" "$fake_mix"
  chmod +x "$fake_mix" "${repo_fixture}/scripts/ci/run_nightly_dialyzer.sh"
  printf 'stale approved child\n' > "${repo_fixture}/priv/plts/dialyzer.plt"
  printf 'preserve repository sibling\n' > "${repo_fixture}/priv/sibling.sentinel"
  printf 'preserve caller child\n' > "${caller_dir}/priv/plts/caller.sentinel"

  output="$(
    cd "$caller_dir"
    MIX_BIN="$fake_mix" \
      DIALYZER_LOG="$dialyzer_log" \
      RINDLE_DIALYZER_TEST_SCENARIO=success \
      RINDLE_DIALYZER_COMMAND_LOG="$command_log" \
      bash "${repo_fixture}/scripts/ci/run_nightly_dialyzer.sh" fresh 2>&1
  )" || status=$?

  if [ "$status" -ne 0 ]; then
    fail_case "${name}: expected exit 0, got ${status}; output=${output}"
  elif [ "$(cat "${repo_fixture}/priv/plts/dialyzer.plt" 2>/dev/null || true)" != "fresh fixture" ]; then
    fail_case "${name}: approved child was not rebuilt"
  elif [ ! -f "${repo_fixture}/priv/sibling.sentinel" ]; then
    fail_case "${name}: repository sibling was removed"
  elif [ ! -f "${caller_dir}/priv/plts/caller.sentinel" ]; then
    fail_case "${name}: caller-directory child was removed"
  else
    pass_case "$name"
  fi

  rm -rf "$case_root"
}

assert_rejected_path() {
  local name="$1" mode="$2" kind="$3" requested_value="${4:-}"
  local case_root repo_fixture fixture_runner fake_mix command_log dialyzer_log external_dir output status=0 commands=""

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/rindle-dialyzer-reject.XXXXXX")"
  repo_fixture="${case_root}/repo"
  fixture_runner="${repo_fixture}/scripts/ci/run_nightly_dialyzer.sh"
  fake_mix="${case_root}/mix"
  command_log="${case_root}/commands.log"
  dialyzer_log="${case_root}/dialyzer.log"
  external_dir="${case_root}/external"

  mkdir -p "${repo_fixture}/scripts/ci" "${repo_fixture}/priv/plts" "$external_dir"
  cp "$runner" "$fixture_runner"
  cp "${repo_root}/scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh" "$fake_mix"
  chmod +x "$fake_mix" "$fixture_runner"
  printf 'preserve repository sibling\n' > "${repo_fixture}/priv/sibling.sentinel"
  printf 'preserve approved child\n' > "${repo_fixture}/priv/plts/internal.sentinel"
  printf 'preserve external target\n' > "${external_dir}/external.sentinel"

  case "$kind" in
    symlink)
      rm "${repo_fixture}/priv/plts/internal.sentinel"
      rmdir "${repo_fixture}/priv/plts"
      ln -s "$external_dir" "${repo_fixture}/priv/plts"
      ;;
    repo-root)
      requested_value="$repo_fixture"
      ;;
    external)
      requested_value="$external_dir"
      ;;
  esac

  if [ "$kind" = "symlink" ]; then
    output="$(
      MIX_BIN="$fake_mix" \
        DIALYZER_LOG="$dialyzer_log" \
        RINDLE_DIALYZER_TEST_SCENARIO=stale_then_success \
        RINDLE_DIALYZER_COMMAND_LOG="$command_log" \
        bash "$fixture_runner" "$mode" 2>&1
    )" || status=$?
  else
    output="$(
      PLT_DIR="$requested_value" \
        MIX_BIN="$fake_mix" \
        DIALYZER_LOG="$dialyzer_log" \
        RINDLE_DIALYZER_TEST_SCENARIO=stale_then_success \
        RINDLE_DIALYZER_COMMAND_LOG="$command_log" \
        bash "$fixture_runner" "$mode" 2>&1
    )" || status=$?
  fi

  if [ -f "$command_log" ]; then
    commands="$(tr '\n' '|' < "$command_log")"
  fi

  if [ "$status" -ne 2 ]; then
    fail_case "${name}: expected exit 2, got ${status}; output=${output}"
  elif [ -n "$commands" ]; then
    fail_case "${name}: fake Mix ran before rejection: ${commands}"
  elif [ ! -f "${repo_fixture}/priv/sibling.sentinel" ]; then
    fail_case "${name}: repository sibling sentinel was removed"
  elif [ ! -f "${external_dir}/external.sentinel" ]; then
    fail_case "${name}: external sentinel was removed"
  elif [ "$kind" != "symlink" ] && [ ! -f "${repo_fixture}/priv/plts/internal.sentinel" ]; then
    fail_case "${name}: approved child sentinel was removed"
  elif [ "${#output}" -gt 256 ] || ! grep -Fq "refusing" <<<"$output"; then
    fail_case "${name}: rejection diagnostic was absent or unbounded"
  elif [ -n "$requested_value" ] && [ "$requested_value" != "." ] && [ "$requested_value" != "/" ] && grep -Fq "$requested_value" <<<"$output"; then
    fail_case "${name}: diagnostic disclosed the rejected resolved value"
  else
    pass_case "$name"
  fi

  rm -rf "$case_root"
}

assert_approved_repo_reset
assert_rejected_path "empty PLT override rejects before work" fresh env ""
assert_rejected_path "dot PLT override rejects before work" fresh env "."
assert_rejected_path "filesystem-root PLT override rejects before work" fresh env "/"
assert_rejected_path "parent traversal rejects before work" fresh env ".."
assert_rejected_path "multi-parent traversal rejects before work" fresh env "../.."
assert_rejected_path "repository-root override rejects before work" fresh repo-root
assert_rejected_path "external absolute override rejects before work" fresh external
assert_rejected_path "fresh symlink escape rejects without deletion" fresh symlink
assert_rejected_path "restored Old PLT symlink escape rejects before analysis" restored symlink
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
