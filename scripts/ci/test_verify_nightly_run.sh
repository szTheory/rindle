#!/usr/bin/env bash
# shellcheck disable=SC2317 # Embedded fake-gh body executes after extraction.
# Exact-run Nightly collector contract exercised against a deterministic fake gh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
collector="${here}/verify_nightly_run.sh"
pass=0
fail=0

record() {
  local name="$1" ok="$2" detail="${3:-}"
  if [ "$ok" = true ]; then
    echo "ok   — ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: ${detail}" >&2
    fail=$((fail + 1))
  fi
}

make_fake_gh() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  awk '/^# BEGIN EMBEDDED FAKE GH$/ {copy=1; next} /^# END EMBEDDED FAKE GH$/ {copy=0} copy' "$0" >"${bin_dir}/gh"
  chmod +x "${bin_dir}/gh"
}

run_case() {
  local name="$1" state="$2" want_exit="$3" temp got=0 poll=0 timeout=2
  temp="$(mktemp -d)"
  make_fake_gh "${temp}/bin"
  make_fake_local_authorities "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/count"
  : >"${temp}/run-list-count"
  : >"${temp}/watch-count"
  : >"${temp}/authority-calls"

  if [ "$state" = watch_rate_limit_persistent ]; then
    poll=1
    timeout=1
  fi

  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_RUN_LIST_COUNT_FILE="${temp}/run-list-count" \
    FAKE_GH_WATCH_COUNT_FILE="${temp}/watch-count" \
    FAKE_GH_STATE="$state" FAKE_AUTHORITY_STATE="$state" FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" dispatch-and-record --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" --poll-seconds "$poll" --timeout-seconds "$timeout" >"${temp}/output" 2>&1 || got=$?

  if [ "$state" = success ] && [ "$got" -eq 0 ]; then
    PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
      FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=success FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
      bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
        --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
        --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?
    if [ "$got" -eq 0 ]; then
      PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
        FAKE_GH_RUN_LIST_COUNT_FILE="${temp}/run-list-count" \
        FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=success FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
        bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
          --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
          --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?
    fi
  fi

  if [ "$got" -eq "$want_exit" ] && { [ "$want_exit" -eq 0 ] && cmp -s "${temp}/receipt.json" <(jq -S . "${temp}/receipt.json") || [ ! -e "${temp}/receipt.json" ]; }; then
    record "$name" true
  else
    record "$name" false "expected exit ${want_exit}, got ${got}; receipt state unexpected"
  fi

  if [ "$state" = success ]; then
    if [ "$(grep -c '^workflow run nightly.yml ' "${temp}/calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^run view 9001 .* --job 6 --log$' "${temp}/calls" || true)" -ge 1 ] &&
       [ "$(grep -c '^run view 9001 .* --job 9 --log$' "${temp}/calls" || true)" -ge 1 ] &&
       [ "$(grep -c '^issue list --repo szTheory/rindle --state open --label nightly-failure --limit 100 --json number,title,body,comments,updatedAt,url$' "${temp}/calls" || true)" -eq 4 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs --root ' "${temp}/authority-calls" || true)" -eq 3 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root ' "${temp}/authority-calls" || true)" -eq 3 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile -e Code.require_file("scripts/maintainer/validate_live_truth.exs")' "${temp}/authority-calls" || true)" -eq 3 ] &&
       [ "$(jq -r '.schema_version' "${temp}/receipt.json")" = 2 ] &&
       [ "$(jq -r '.local_authorities.census.ledger_path' "${temp}/receipt.json")" = .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json ] &&
       [ "$(jq -r '.local_authorities.census.ledger_sha256' "${temp}/receipt.json")" = 80c9c6808f18a8dd51489e9da11fafc4f8b00d993a615348a773056f81af8744 ] &&
       [ "$(jq -r '.local_authorities.census.ledger_blob' "${temp}/receipt.json")" = cccccccccccccccccccccccccccccccccccccccc ] &&
       [ "$(jq -r '.local_authorities.census.ledger_commit' "${temp}/receipt.json")" = dddddddddddddddddddddddddddddddddddddddd ] &&
       [ "$(jq -r '.local_authorities.census.subject_sha' "${temp}/receipt.json")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ] &&
       [ "$(jq -r '.local_authorities.census.receipt.marker' "${temp}/receipt.json")" = immutable-object ] &&
       [ "$(jq -r '.local_authorities.live_truth.model_sha256 | length' "${temp}/receipt.json")" -eq 64 ] &&
       grep -q '^git -C .* show dddddddddddddddddddddddddddddddddddddddd:.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json$' "${temp}/authority-calls" &&
       grep -Eq -- '--ledger /.*nightly-authority\..*/ledger.json' "${temp}/authority-calls" &&
       ! grep -Eq -- '--ledger .*/projects/rindle/.planning/' "${temp}/authority-calls" &&
       ! grep -Eq '^(issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
      record "success argv is one dispatch plus read-only inspection" true
    else
      record "success argv is one dispatch plus read-only inspection" false "unsafe or missing call"
    fi
  fi

  if [ "$state" = old_runs_then_exact ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -eq 2 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^run view 9001 ' "${temp}/calls" || true)" -ge 1 ] &&
       ! grep -Eq '^run (watch|view) 8000 ' "${temp}/calls" &&
       [ "$(jq -r '.run_id' "${temp}/receipt.json" 2>/dev/null || true)" = 9001 ]; then
      record "old history waits for and selects only the exact run" true
    else
      record "old history waits for and selects only the exact run" false "unexpected polling or selected-run argv"
    fi
  fi

  if [ "$state" = same_second_old_then_new ]; then
    if [ "$got" -eq 0 ] &&
       [ "$(grep -c '^run list ' "${temp}/calls" || true)" -eq 2 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 1 ] &&
       ! grep -Eq '^run (watch|view) 8000 ' "${temp}/calls" &&
       [ "$(jq -r '.run_id' "${temp}/receipt.json" 2>/dev/null || true)" = 9001 ]; then
      record "same-second pre-existing run cannot impersonate the new dispatch" true
    else
      record "same-second pre-existing run cannot impersonate the new dispatch" false "snapshot subtraction did not select only the new ID"
    fi
  fi

  if [ "$state" = same_second_old_only ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -gt 1 ] &&
       ! grep -Eq '^run (watch|view) ' "${temp}/calls" &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "same-second old-only history polls without selecting the old run" true
    else
      record "same-second old-only history polls without selecting the old run" false "old snapshot ID was treated as collector-owned"
    fi
  fi

  if [ "$state" = pre_list_failure ] || [ "$state" = malformed_pre_list ] ||
     [ "$state" = duplicate_pre_ids ] || [ "$state" = non_integer_pre_id ]; then
    if ! grep -q '^workflow run ' "${temp}/calls" &&
       ! grep -Eq '^run (watch|view) ' "${temp}/calls" &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "${state} rejects before dispatch" true
    else
      record "${state} rejects before dispatch" false "invalid pre-snapshot inventory crossed the mutation boundary"
    fi
  fi

  if [ "$state" = unrelated_new_then_exact ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -eq 3 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 1 ] &&
       ! grep -Eq '^run (watch|view) 7000 ' "${temp}/calls" &&
       [ "$(jq -r '.run_id' "${temp}/receipt.json" 2>/dev/null || true)" = 9001 ]; then
      record "unrelated new run is ignored until one exact new ID appears" true
    else
      record "unrelated new run is ignored until one exact new ID appears" false "unrelated inventory changed ownership selection"
    fi
  fi

  if [ "$state" = old_exact_delayed_exact_new ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -eq 3 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 1 ] &&
       ! grep -Eq '^run (watch|view) 8000 ' "${temp}/calls"; then
      record "old exact run remains excluded while the new exact run is delayed" true
    else
      record "old exact run remains excluded while the new exact run is delayed" false "polling did not preserve the pre-dispatch exclusion set"
    fi
  fi

  if [ "$state" = detail_id_mismatch ]; then
    if [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^run view 9001 .* --json ' "${temp}/calls" || true)" -eq 1 ] &&
       ! grep -Eq '^run view 9001 .* --job ' "${temp}/calls" &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "selected ID must equal the detailed run databaseId" true
    else
      record "selected ID must equal the detailed run databaseId" false "detail identity was not cross-bound before evidence collection"
    fi
  fi

  if [ "$state" = success ]; then
    first_list_line="$(grep -n '^run list ' "${temp}/calls" | head -1 | cut -d: -f1)"
    dispatch_line="$(grep -n '^workflow run nightly.yml ' "${temp}/calls" | head -1 | cut -d: -f1)"
    if [ -n "$first_list_line" ] && [ -n "$dispatch_line" ] &&
       [ "$first_list_line" -lt "$dispatch_line" ]; then
      record "initial run inventory snapshot precedes the sole dispatch" true
    else
      record "initial run inventory snapshot precedes the sole dispatch" false "command log order did not prove snapshot-before-dispatch"
    fi
  fi

  if [ "$state" = multiple_new_after_dispatch ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -eq 2 ] &&
       ! grep -Eq '^run (watch|view) ' "${temp}/calls" &&
       grep -q 'ambiguous.*new exact diagnostic run' "${temp}/output" &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "multiple new exact matches fail immediately before downstream calls" true
    else
      record "multiple new exact matches fail immediately before downstream calls" false "post-dispatch set ambiguity was not rejected at the selector boundary"
    fi
  fi

  if [ "$state" = watch_rate_limit_once ]; then
    if [ "$got" -eq 0 ] &&
       [ "$(grep -c '^workflow run nightly.yml ' "${temp}/calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -eq 2 ] &&
       [ "$(jq -r '.run_id' "${temp}/receipt.json" 2>/dev/null || true)" = 9001 ] &&
       ! grep -Eq '^(issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
      record "transient watch rate limit preserves one dispatch-owned run" true
    else
      record "transient watch rate limit preserves one dispatch-owned run" false "recovery changed mutation count or selected identity"
    fi
  fi

  if [ "$state" = watch_rate_limit_persistent ]; then
    if [ "$got" -ne 0 ] &&
       [ "$(grep -c '^workflow run nightly.yml ' "${temp}/calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^run watch 9001 ' "${temp}/calls" || true)" -ge 1 ] &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "persistent watch rate limit exhausts the original deadline" true
    else
      record "persistent watch rate limit exhausts the original deadline" false "persistent recovery was not bounded and receipt-free"
    fi
  fi

  if [ "$state" = timeout ]; then
    if [ "$(grep -c '^run list ' "${temp}/calls" || true)" -gt 1 ] &&
       ! grep -Eq '^run (watch|view) ' "${temp}/calls" &&
       [ ! -e "${temp}/receipt.json" ]; then
      record "zero exact matches poll until timeout without a receipt" true
    else
      record "zero exact matches poll until timeout without a receipt" false "zero-match polling or receipt cleanup was incorrect"
    fi
  fi
  rm -rf "$temp"
}

collect_valid_receipt() {
  local temp="$1" got=0
  make_fake_gh "${temp}/bin"
  make_fake_local_authorities "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/count"
  : >"${temp}/run-list-count"
  : >"${temp}/authority-calls"

  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_RUN_LIST_COUNT_FILE="${temp}/run-list-count" \
    FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=success FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" dispatch-and-record --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" --poll-seconds 0 --timeout-seconds 2 >/dev/null 2>&1 || got=$?

  [ "$got" -eq 0 ] && [ -s "${temp}/receipt.json" ]
}

make_fake_local_authorities() {
  local bin_dir="$1"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "git %s\n" "$*" >>"$FAKE_AUTHORITY_LOG"' \
    'if [ "${1-}" = -C ]; then shift 2; fi' \
    'case "${1-} ${2-}" in' \
    '  "status --porcelain") [ "${FAKE_AUTHORITY_STATE:-success}" != dirty_ledger ] || printf " M %s\n" "${4-}" ;;' \
    '  "ls-files --error-unmatch") [ "${FAKE_AUTHORITY_STATE:-success}" != untracked_ledger ] || exit 1 ;;' \
    '  "log -1") printf "%s\n" dddddddddddddddddddddddddddddddddddddddd ;;' \
    '  "rev-parse dddddddddddddddddddddddddddddddddddddddd:.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json")' \
    '    [ "${FAKE_AUTHORITY_STATE:-success}" != missing_path_at_commit ] || exit 1' \
    '    if [ "${FAKE_AUTHORITY_STATE:-success}" = blob_mismatch ]; then' \
    '      printf "%s\n" eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' \
    '    else' \
    '      printf "%s\n" cccccccccccccccccccccccccccccccccccccccc' \
    '    fi' \
    '    ;;' \
    '  "show dddddddddddddddddddddddddddddddddddddddd:.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json")' \
    '    if [ "${FAKE_AUTHORITY_STATE:-success}" = hash_mismatch ]; then' \
    '      printf "forged ledger bytes\n"' \
    '    else' \
    '      printf "fake immutable ledger\n"' \
    '    fi' \
    '    ;;' \
    '  "worktree add")' \
    '    [ "${FAKE_AUTHORITY_STATE:-success}" != bad_local_authority ] || exit 44' \
    '    mkdir -p "$4"' \
    '    ;;' \
    '  "worktree remove") rm -rf "$4" ;;' \
    '  *) echo "unexpected fake git call: $*" >&2; exit 43 ;;' \
    'esac' >"${bin_dir}/git"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "mix %s\n" "$*" >>"$FAKE_AUTHORITY_LOG"' \
    'if [ "${FAKE_AUTHORITY_STATE:-success}" = local_validator_failure ] && printf "%s\n" "$*" | grep -q "validate_live_truth.exs"; then exit 44; fi' \
    'if [ "${FAKE_AUTHORITY_STATE:-success}" = bad_local_authority ] && printf "%s\n" "$*" | grep -q "validate_evidence_census.exs"; then exit 44; fi' \
    'if printf "%s\n" "$*" | grep -q "evidence_census.exs"; then' \
    '  output=""' \
    '  while [ "$#" -gt 0 ]; do' \
    '    if [ "$1" = --output ]; then output="$2"; break; fi' \
    '    shift' \
    '  done' \
    '  marker=immutable-object' \
    '  [ "${FAKE_AUTHORITY_STATE:-success}" != census_receipt_changed ] || marker=forged' \
    '  [ -z "$output" ] || printf "{\"marker\":\"%s\",\"schema_version\":1,\"source_sha\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}\n" "$marker" >"$output"' \
    'elif printf "%s\n" "$*" | grep -q "validate_live_truth.exs" && printf "%s\n" "$*" | grep -q -- "--format"; then' \
    '  version=0.4.6' \
    '  [ "${FAKE_AUTHORITY_STATE:-success}" != live_model_changed ] || version=9.9.9' \
    '  printf "{\"authority_root\":\"ephemeral\",\"schema_version\":1,\"version\":\"%s\"}\n" "$version"' \
    'fi' >"${bin_dir}/mix"
  chmod +x "${bin_dir}/git" "${bin_dir}/mix"
}

verify_mutation_case() {
  local name="$1" filter="$2" temp got=0
  temp="$(mktemp -d)"

  if ! collect_valid_receipt "$temp"; then
    record "$name" false "could not collect baseline receipt"
    rm -rf "$temp"
    return
  fi

  jq "$filter" "${temp}/receipt.json" >"${temp}/mutated.json"
  make_fake_local_authorities "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/authority-calls"
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=success FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/mutated.json" >/dev/null 2>&1 || got=$?

  if [ "$got" -ne 0 ] &&
     ! grep -Eq '^(workflow run|issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
    record "$name" true
  else
    record "$name" false "mutated receipt exit ${got}; unsafe call recorded"
  fi
  rm -rf "$temp"
}

verify_live_state_case() {
  local name="$1" state="$2" temp got=0 before_sha after_sha
  temp="$(mktemp -d)"

  if ! collect_valid_receipt "$temp"; then
    record "$name" false "could not collect baseline receipt"
    rm -rf "$temp"
    return
  fi

  make_fake_local_authorities "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/count"
  : >"${temp}/authority-calls"
  before_sha="$(shasum -a 256 "${temp}/receipt.json" | awk '{print $1}')"
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_STATE="$state" FAKE_AUTHORITY_STATE="$state" FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?
  after_sha="$(shasum -a 256 "${temp}/receipt.json" | awk '{print $1}')"

  if [ "$got" -ne 0 ] &&
     [ "$before_sha" = "$after_sha" ] &&
     ! grep -Eq '^(workflow run|issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
    record "$name" true
  else
    record "$name" false "live authority failure was accepted (exit ${got})"
  fi
  rm -rf "$temp"
}

verify_worktree_independence_case() {
  local temp got=0
  temp="$(mktemp -d)"
  if ! collect_valid_receipt "$temp"; then
    record "caller-worktree ledger edit cannot change stored authority" false "could not collect baseline receipt"
    rm -rf "$temp"
    return
  fi

  make_fake_local_authorities "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/authority-calls"
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=current_worktree_edit FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?

  if [ "$got" -eq 0 ] &&
     ! grep -Eq '^git -C .* (status|ls-files) ' "${temp}/authority-calls" &&
     grep -q '^git -C .* show dddddddddddddddddddddddddddddddddddddddd:.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json$' "${temp}/authority-calls" &&
     ! grep -Eq '^(workflow run|issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
    record "caller-worktree ledger edit cannot change stored authority" true
  else
    record "caller-worktree ledger edit cannot change stored authority" false "verification consulted mutable ledger state"
  fi
  rm -rf "$temp"
}

if [ ! -x "$collector" ]; then
  echo "FAIL — collector does not exist or is not executable: ${collector}" >&2
  exit 1
fi

if [ "${VERIFY_NIGHTLY_TEST_SCOPE:-}" = diagnostic-topology ]; then
  run_case "workflow_dispatch accepts the exact 11-job diagnostic topology" diagnostic_topology 0
  echo "—"
  echo "passed: ${pass}  failed: ${fail}"
  [ "$pass" -gt 0 ] && [ "$fail" -eq 0 ]
  exit
fi

run_case "exact first-attempt run writes canonical receipt" success 0
run_case "older runs appear before the exact run" old_runs_then_exact 0
run_case "same-second old run is excluded when one new run appears" same_second_old_then_new 0
run_case "same-second old-only history has zero new matches" same_second_old_only 1
run_case "multiple new exact matches are ambiguous" multiple_new_after_dispatch 1
run_case "pre-dispatch run-list API failure" pre_list_failure 1
run_case "malformed pre-dispatch run inventory" malformed_pre_list 1
run_case "duplicate pre-dispatch run IDs" duplicate_pre_ids 1
run_case "non-integer pre-dispatch run ID" non_integer_pre_id 1
run_case "unrelated new run precedes the exact new run" unrelated_new_then_exact 0
run_case "old exact run precedes a delayed exact new run" old_exact_delayed_exact_new 0
run_case "post-dispatch malformed inventory" malformed_post_list 1
run_case "post-dispatch duplicate IDs" duplicate_post_ids 1
run_case "selected run detail ID mismatch" detail_id_mismatch 1
run_case "transient watch rate limit" watch_rate_limit_once 0
run_case "persistent watch rate limit" watch_rate_limit_persistent 1
if [ "${VERIFY_NIGHTLY_TEST_SCOPE:-}" = ownership ]; then
  echo "—"
  echo "passed: ${pass}  failed: ${fail}"
  [ "$pass" -gt 0 ] && [ "$fail" -eq 0 ]
  exit
fi
for state in foreign_repository foreign_workflow missing_ref foreign_sha foreign_run_sha foreign_run_ref \
  foreign_run_workflow rerun missing_job extra_job red_job skipped_job cancelled_job nonterminal red_run \
  missing_fresh missing_restored unsupported_elixir_11_17 unsupported_elixir_1_170 unsupported_otp_127 \
  bad_local_authority missing_cache stale_rebuild red_verdict \
  incident_changed timeout api_failure watch_failure; do
  run_case "$state fails closed" "$state" 1
done
run_case "dirty ledger fails closed before collection" dirty_ledger 2
run_case "untracked ledger fails closed before collection" untracked_ledger 2

while IFS=$'\t' read -r name filter; do
  verify_mutation_case "$name" "$filter"
done <<'MUTATIONS'
created_at mutation fails closed	.created_at = "2026-09-09T12:00:02Z"
schema version mutation fails closed	.schema_version = 1
repository mutation fails closed	.repository = "other/project"
workflow mutation fails closed	.workflow = "other.yml"
event mutation fails closed	.event = "schedule"
subject SHA mutation fails closed	.subject_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
remote ref mutation fails closed	.remote_ref = "other-ref"
run id mutation fails closed	.run_id = 999
run attempt mutation fails closed	.run_attempt = 2
conclusion mutation fails closed	.conclusion = "failure"
job id mutation fails closed	.jobs[0].id = 999
job name mutation fails closed	.jobs[0].name = "Forged"
job status mutation fails closed	.jobs[0].status = "queued"
job conclusion mutation fails closed	.jobs[0].conclusion = "failure"
job order mutation fails closed	.jobs |= reverse
duplicate job mutation fails closed	.jobs[1] = .jobs[0]
strict verdict mutation fails closed	.strict_verdict.verdict = "red"
strict source job mutation fails closed	.strict_verdict.summary_job = "Dialyzer"
requested Elixir mutation fails closed	.dialyzer.requested_elixir = "1.18"
requested OTP mutation fails closed	.dialyzer.requested_otp = "28"
resolved Elixir mutation fails closed	.dialyzer.resolved_elixir = "v1.17.4-otp-27"
resolved OTP mutation fails closed	.dialyzer.resolved_otp = "OTP-27.3.4.18"
resolved Elixir 11.17 near-match fails closed	.dialyzer.resolved_elixir = "v11.17.3-otp-27"
resolved Elixir 1.170 near-match fails closed	.dialyzer.resolved_elixir = "v1.170.3-otp-27"
resolved OTP 127 near-match fails closed	.dialyzer.resolved_otp = "OTP-127.3.4.17"
cache key mutation fails closed	.dialyzer.cache_key += "-forged"
fresh status mutation fails closed	.dialyzer.fresh.status = "fail"
fresh builds mutation fails closed	.dialyzer.fresh.builds = 2
fresh analyses mutation fails closed	.dialyzer.fresh.analyses = 2
restored status mutation fails closed	.dialyzer.restored.status = "fail"
restored analyses mutation fails closed	.dialyzer.restored.analyses = 2
stale rebuild mutation fails closed	.dialyzer.stale_rebuilds = 1
preflight repository mutation fails closed	.preflight.repository = "other/project"
preflight workflow mutation fails closed	.preflight.workflow = "other.yml"
preflight ref mutation fails closed	.preflight.remote_ref = "other-ref"
preflight SHA mutation fails closed	.preflight.subject_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
preflight status mutation fails closed	.preflight.status = "fail"
missing top-level key fails closed	del(.created_at)
extra top-level key fails closed	.extra = true
extra job key fails closed	.jobs[0].extra = true
extra Dialyzer key fails closed	.dialyzer.extra = true
extra fresh key fails closed	.dialyzer.fresh.extra = true
extra restored key fails closed	.dialyzer.restored.extra = true
extra strict-verdict key fails closed	.strict_verdict.extra = true
extra preflight key fails closed	.preflight.extra = true
both incident snapshots forged together fail closed	.incident_snapshot_before[0].body = "forged" | .incident_snapshot_after[0].body = "forged"
local census authority removed fails closed	del(.local_authorities.census)
local live-truth authority removed fails closed	del(.local_authorities.live_truth)
extra local-authority key fails closed	.local_authorities.extra = {"status":"pass"}
census status mutation fails closed	.local_authorities.census.status = "fail"
census ledger path mutation fails closed	.local_authorities.census.ledger_path = "other.json"
census ledger SHA-256 mutation fails closed	.local_authorities.census.ledger_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
census ledger blob mutation fails closed	.local_authorities.census.ledger_blob = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
census ledger commit mutation fails closed	.local_authorities.census.ledger_commit = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
census subject mutation fails closed	.local_authorities.census.subject_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
census detailed receipt mutation fails closed	.local_authorities.census.receipt.marker = "forged"
missing census ledger field fails closed	del(.local_authorities.census.ledger_blob)
extra census key fails closed	.local_authorities.census.extra = true
live-truth status mutation fails closed	.local_authorities.live_truth.status = "fail"
live-truth subject mutation fails closed	.local_authorities.live_truth.subject_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
live-truth model digest mutation fails closed	.local_authorities.live_truth.model_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
missing live-truth field fails closed	del(.local_authorities.live_truth.model_sha256)
extra live-truth key fails closed	.local_authorities.live_truth.extra = true
MUTATIONS

if grep -Eq 'contains\("1\.17"\)|contains\("27"\)' "$collector"; then
  record "receipt validation has no substring toolchain fallback" false "found contains() version classification"
else
  record "receipt validation has no substring toolchain fallback" true
fi

verify_live_state_case "fresh incident drift fails closed" incident_verify_changed
verify_live_state_case "local validator failure fails closed" local_validator_failure
verify_live_state_case "ledger path missing at recorded commit fails closed" missing_path_at_commit
verify_live_state_case "ledger blob mismatch fails closed" blob_mismatch
verify_live_state_case "materialized ledger hash mismatch fails closed" hash_mismatch
verify_live_state_case "regenerated census receipt drift fails closed" census_receipt_changed
verify_live_state_case "regenerated live-truth model drift fails closed" live_model_changed
verify_worktree_independence_case

echo "—"
echo "passed: ${pass}  failed: ${fail}"
status=0
[ "$pass" -gt 0 ] && [ "$fail" -eq 0 ] || status=1
exit "$status"

# BEGIN EMBEDDED FAKE GH
#!/usr/bin/env bash
# shellcheck disable=SC2317
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
state="${FAKE_GH_STATE:-success}"
sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
ref=phase-133-evidence-aaaaaaaaaaaa
run_id=9001
created=2026-09-09T12:00:01Z

if [ "$state" = api_failure ] && [ "${1-}" != workflow ]; then
  echo "simulated GitHub API failure" >&2
  exit 41
fi

case "${1-} ${2-}" in
  "repo view")
    [ "$state" != foreign_repository ] || repo=other/project
    jq -cn --arg name "${repo:-szTheory/rindle}" '{nameWithOwner:$name}'
    ;;
  "workflow view")
    [ "$state" != foreign_workflow ] || { printf 'name: Other\non:\n  workflow_dispatch:\n'; exit; }
    printf 'name: Nightly\non:\n  workflow_dispatch:\n'
    ;;
  "api repos/szTheory/rindle/git/ref/heads/phase-133-evidence-aaaaaaaaaaaa")
    [ "$state" != missing_ref ] || exit 1
    [ "$state" != foreign_sha ] || sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    jq -cn --arg ref "refs/heads/$ref" --arg sha "$sha" '{ref:$ref,object:{sha:$sha}}'
    ;;
  "workflow run") exit 0 ;;
  "run list")
    dispatched="$(grep -c '^workflow run nightly.yml ' "$FAKE_GH_LOG" || true)"
    if [ "$state" = pre_list_failure ] && [ "$dispatched" -eq 0 ]; then
      echo "simulated pre-dispatch run-list failure" >&2
      exit 41
    fi
    if [ "$state" = malformed_pre_list ] && [ "$dispatched" -eq 0 ]; then
      printf '{}\n'
      exit
    fi
    if [ "$state" = duplicate_pre_ids ] && [ "$dispatched" -eq 0 ]; then
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[{attempt:1,conclusion:"success",createdAt:$created,databaseId:8000,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"},{attempt:1,conclusion:"success",createdAt:$created,databaseId:8000,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"}]'
      exit
    fi
    if [ "$state" = non_integer_pre_id ] && [ "$dispatched" -eq 0 ]; then
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[{attempt:1,conclusion:"success",createdAt:$created,databaseId:8000.5,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"}]'
      exit
    fi
    [ "$state" != timeout ] || { printf '[]\n'; exit; }
    if [ "$state" = malformed_post_list ] && [ "$dispatched" -gt 0 ]; then
      printf '{}\n'
      exit
    fi
    if [ "$state" = duplicate_post_ids ] && [ "$dispatched" -gt 0 ]; then
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"},{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"}]'
      exit
    fi
    if [ "$state" = same_second_old_then_new ] || [ "$state" = same_second_old_only ]; then
      old="$(jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '{attempt:1,conclusion:"success",createdAt:$created,databaseId:8000,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"}')"
      if [ "$state" = same_second_old_only ] || [ "$dispatched" -eq 0 ]; then
        jq -cn --argjson old "$old" '[$old]'
        exit
      fi
      jq -cn --argjson old "$old" --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[$old,{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"}]'
      exit
    fi
    if [ "$state" = multiple_new_after_dispatch ]; then
      if [ "$dispatched" -eq 0 ]; then
        printf '[]\n'
        exit
      fi
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"},{attempt:1,conclusion:"success",createdAt:$created,databaseId:9002,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9002",workflowName:"Nightly"}]'
      exit
    fi
    if [ "$state" = unrelated_new_then_exact ] || [ "$state" = old_exact_delayed_exact_new ]; then
      list_count="$(cat "$FAKE_GH_RUN_LIST_COUNT_FILE" 2>/dev/null || printf 0)"
      list_count=$((list_count + 1))
      printf '%s' "$list_count" >"$FAKE_GH_RUN_LIST_COUNT_FILE"
      if [ "$state" = unrelated_new_then_exact ]; then
        unrelated="$(jq -cn --arg ref "$ref" --arg created "$created" \
          '{attempt:1,conclusion:"success",createdAt:$created,databaseId:7000,event:"workflow_dispatch",headBranch:$ref,headSha:"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",status:"completed",url:"https://github.test/runs/7000",workflowName:"Nightly"}')"
        if [ "$list_count" -eq 1 ]; then printf '[]\n'; exit; fi
        if [ "$list_count" -eq 2 ]; then jq -cn --argjson unrelated "$unrelated" '[$unrelated]'; exit; fi
        jq -cn --argjson unrelated "$unrelated" --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
          '[$unrelated,{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"}]'
        exit
      fi
      old="$(jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '{attempt:1,conclusion:"success",createdAt:$created,databaseId:8000,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"}')"
      if [ "$list_count" -le 2 ]; then jq -cn --argjson old "$old" '[$old]'; exit; fi
      jq -cn --argjson old "$old" --arg sha "$sha" --arg ref "$ref" --arg created "$created" \
        '[$old,{attempt:1,conclusion:"success",createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/9001",workflowName:"Nightly"}]'
      exit
    fi
    if [ "$state" = old_runs_then_exact ]; then
      list_count="$(cat "$FAKE_GH_RUN_LIST_COUNT_FILE" 2>/dev/null || printf 0)"
      list_count=$((list_count + 1))
      printf '%s' "$list_count" >"$FAKE_GH_RUN_LIST_COUNT_FILE"
      if [ "$list_count" -eq 1 ]; then
        jq -cn --arg sha "$sha" --arg ref "$ref" \
          '[{attempt:1,conclusion:"success",createdAt:"2026-09-09T11:00:00Z",databaseId:8000,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,status:"completed",url:"https://github.test/runs/8000",workflowName:"Nightly"}]'
        exit
      fi
    fi
    if [ "$dispatched" -eq 0 ]; then
      printf '[]\n'
      exit
    fi
    run_sha="$sha"; run_ref="$ref"; run_workflow=Nightly; attempt=1; status=completed; conclusion=success
    [ "$state" != foreign_run_sha ] || run_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    [ "$state" != foreign_run_ref ] || run_ref=other-ref
    [ "$state" != foreign_run_workflow ] || run_workflow=Other
    [ "$state" != rerun ] || attempt=2
    [ "$state" != nonterminal ] || status=in_progress
    [ "$state" != red_run ] || conclusion=failure
    jq -cn --argjson attempt "$attempt" --arg conclusion "$conclusion" --arg createdAt "$created" \
      --argjson databaseId "$run_id" --arg headBranch "$run_ref" --arg headSha "$run_sha" \
      --arg status "$status" --arg workflowName "$run_workflow" \
      '[{attempt:$attempt,conclusion:$conclusion,createdAt:$createdAt,databaseId:$databaseId,event:"workflow_dispatch",headBranch:$headBranch,headSha:$headSha,status:$status,url:"https://github.test/runs/9001",workflowName:$workflowName}]'
    ;;
  "run watch")
    if [ "$state" = watch_rate_limit_once ] || [ "$state" = watch_rate_limit_persistent ]; then
      watch_count="$(cat "$FAKE_GH_WATCH_COUNT_FILE" 2>/dev/null || printf 0)"
      watch_count=$((watch_count + 1))
      printf '%s' "$watch_count" >"$FAKE_GH_WATCH_COUNT_FILE"
      if [ "$state" = watch_rate_limit_once ] && [ "$watch_count" -eq 1 ]; then
        echo "HTTP 403: API rate limit exceeded for user ID 1234" >&2
        exit 42
      fi
      if [ "$state" = watch_rate_limit_persistent ]; then
        echo "You have exceeded a secondary rate limit. Please wait a few minutes before you try again." >&2
        exit 42
      fi
    fi
    [ "$state" != watch_failure ] || exit 42
    ;;
  "run view")
    if printf '%s\n' "$*" | grep -q -- '--log'; then
      if printf '%s\n' "$*" | grep -q -- '--job 6'; then
        resolved_elixir=v1.17.3-otp-27
        resolved_otp=OTP-27.3.4.17
        [ "$state" != unsupported_elixir_11_17 ] || resolved_elixir=v11.17.3-otp-27
        [ "$state" != unsupported_elixir_1_170 ] || resolved_elixir=v1.170.3-otp-27
        [ "$state" != unsupported_otp_127 ] || resolved_otp=OTP-127.3.4.17
        printf '%s\n' "Dialyzer\tSet up Elixir\tResolved Elixir version: ${resolved_elixir}" "Dialyzer\tSet up Elixir\tResolved OTP version: ${resolved_otp}"
        [ "$state" = missing_fresh ] || printf '%s\n' 'Dialyzer\tDialyzer (fresh PLT)\tnightly-dialyzer mode=fresh action=build-plt' 'Dialyzer\tDialyzer (fresh PLT)\tnightly-dialyzer mode=fresh attempt=1 action=analyze'
        [ "$state" = missing_cache ] || printf '%s\n' "Dialyzer\tSave PLT cache\tCache saved with key: plt-v3-Linux-X64-otp${resolved_otp}-elixir${resolved_elixir}-inputhash"
        [ "$state" = missing_restored ] || printf '%s\n' 'Dialyzer\tDialyzer (restored PLT)\tnightly-dialyzer mode=restored attempt=1 action=analyze'
        [ "$state" != stale_rebuild ] || printf '%s\n' 'Dialyzer\tDialyzer (restored PLT)\tnightly-dialyzer mode=restored attempt=1 fingerprint=old-plt recovery=rebuild-once'
      elif printf '%s\n' "$*" | grep -q -- '--job 9'; then
        [ "$state" = red_verdict ] && verdict=red || verdict=green
        printf '%s\n' "Nightly Summary\\tEnforce strict Nightly verdict\\ttest \"$verdict\" = \"green\""
      else
        echo "unexpected log job: $*" >&2
        exit 43
      fi
    else
      jobs='[{"databaseId":1,"name":"Compat Matrix (1.15, 26)","status":"completed","conclusion":"success"},{"databaseId":2,"name":"Compat Matrix (1.16, 26)","status":"completed","conclusion":"success"},{"databaseId":3,"name":"Compat Matrix (1.17, 27)","status":"completed","conclusion":"success"},{"databaseId":4,"name":"Compat Matrix (1.18, 27)","status":"completed","conclusion":"success"},{"databaseId":5,"name":"Compat Matrix (1.18, 28)","status":"completed","conclusion":"success"},{"databaseId":6,"name":"Dialyzer","status":"completed","conclusion":"success"},{"databaseId":7,"name":"GCS Soak (real bucket)","status":"completed","conclusion":"success"},{"databaseId":8,"name":"Package Consumer GCS Live Proof","status":"completed","conclusion":"success"},{"databaseId":9,"name":"Nightly Summary","status":"completed","conclusion":"success"},{"databaseId":10,"name":"Nightly Incident Lifecycle","status":"completed","conclusion":"skipped"},{"databaseId":11,"name":"Persist Nightly Incident Verdict","status":"completed","conclusion":"skipped"}]'
      [ "$state" != missing_job ] || jobs="$(jq 'del(.[0])' <<<"$jobs")"
      [ "$state" != extra_job ] || jobs="$(jq '. + [{databaseId:12,name:"Unexpected",status:"completed",conclusion:"success"}]' <<<"$jobs")"
      [ "$state" != red_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="failure" else . end)' <<<"$jobs")"
      [ "$state" != skipped_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="skipped" else . end)' <<<"$jobs")"
      [ "$state" != cancelled_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="cancelled" else . end)' <<<"$jobs")"
      attempt=1; status=completed; conclusion=success
      [ "$state" != rerun ] || attempt=2
      [ "$state" != nonterminal ] || status=in_progress
      [ "$state" != red_run ] || conclusion=failure
      detail_id=9001
      [ "$state" != detail_id_mismatch ] || detail_id=9002
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" --argjson jobs "$jobs" --argjson attempt "$attempt" --argjson databaseId "$detail_id" --arg status "$status" --arg conclusion "$conclusion" '{attempt:$attempt,conclusion:$conclusion,createdAt:$created,databaseId:$databaseId,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,jobs:$jobs,status:$status,url:"https://github.test/runs/9001",workflowName:"Nightly"}'
    fi
    ;;
  "issue list")
    count="$(cat "$FAKE_GH_COUNT_FILE" 2>/dev/null || printf 0)"; count=$((count + 1)); printf '%s' "$count" >"$FAKE_GH_COUNT_FILE"
    body=nightly-run:8000:1
    [ "$state" != incident_changed ] || { [ "$count" -eq 1 ] || body=nightly-run:9001:1; }
    [ "$state" != incident_verify_changed ] || body=nightly-run:forged:1
    jq -cn --arg body "$body" '[{number:88,title:"Nightly CI failure",body:$body,comments:[],updatedAt:"2026-09-09T11:00:00Z",url:"https://github.test/issues/88"}]'
    ;;
  *) echo "unexpected fake gh call: $*" >&2; exit 43 ;;
esac
# END EMBEDDED FAKE GH
