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
  local name="$1" state="$2" want_exit="$3" temp got=0 local_authorities
  temp="$(mktemp -d)"
  make_fake_gh "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/count"
  : >"${temp}/run-list-count"

  local_authorities='{"census":{"status":"pass"},"live_truth":{"status":"pass"}}'
  [ "$state" != bad_local_authority ] || local_authorities='{"census":{"status":"fail"},"live_truth":{"status":"pass"}}'
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_RUN_LIST_COUNT_FILE="${temp}/run-list-count" \
    FAKE_GH_STATE="$state" NIGHTLY_LOCAL_AUTHORITIES_JSON="$local_authorities" \
    NIGHTLY_NOW=2026-09-09T12:00:00Z \
    bash "$collector" dispatch-and-record --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" --poll-seconds 0 --timeout-seconds 2 >/dev/null 2>&1 || got=$?

  if [ "$state" = success ] && [ "$got" -eq 0 ]; then
    make_fake_local_authorities "${temp}/bin"
    : >"${temp}/authority-calls"
    PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
      FAKE_GH_STATE=success FAKE_AUTHORITY_STATE=success FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
      bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
        --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
        --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?
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
       [ "$(grep -c '^issue list --repo szTheory/rindle --state open --label nightly-failure --limit 100 --json number,title,body,comments,updatedAt,url$' "${temp}/calls" || true)" -eq 3 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs --root ' "${temp}/authority-calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs --root ' "${temp}/authority-calls" || true)" -eq 1 ] &&
       [ "$(grep -c '^mix run --no-deps-check --no-compile -e Code.require_file("scripts/maintainer/validate_live_truth.exs")' "${temp}/authority-calls" || true)" -eq 1 ] &&
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
  rm -rf "$temp"
}

collect_valid_receipt() {
  local temp="$1" got=0
  make_fake_gh "${temp}/bin"
  : >"${temp}/calls"
  : >"${temp}/count"
  : >"${temp}/run-list-count"

  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_RUN_LIST_COUNT_FILE="${temp}/run-list-count" \
    FAKE_GH_STATE=success \
    NIGHTLY_LOCAL_AUTHORITIES_JSON='{"census":{"status":"pass"},"live_truth":{"status":"pass"}}' \
    NIGHTLY_NOW=2026-09-09T12:00:00Z \
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
    'case "${1-} ${2-}" in' \
    '  "worktree add") mkdir -p "$4" ;;' \
    '  "worktree remove") rm -rf "$4" ;;' \
    '  *) echo "unexpected fake git call: $*" >&2; exit 43 ;;' \
    'esac' >"${bin_dir}/git"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "mix %s\n" "$*" >>"$FAKE_AUTHORITY_LOG"' \
    'if [ "${FAKE_AUTHORITY_STATE:-success}" = local_validator_failure ] && printf "%s\n" "$*" | grep -q "validate_live_truth.exs"; then exit 44; fi' \
    'if printf "%s\n" "$*" | grep -q "evidence_census.exs"; then' \
    '  output=""' \
    '  while [ "$#" -gt 0 ]; do' \
    '    if [ "$1" = --output ]; then output="$2"; break; fi' \
    '    shift' \
    '  done' \
    '  [ -z "$output" ] || printf "{\"schema_version\":1}\n" >"$output"' \
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
  local name="$1" state="$2" temp got=0
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
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_STATE="$state" FAKE_AUTHORITY_STATE="$state" FAKE_AUTHORITY_LOG="${temp}/authority-calls" \
    bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" >/dev/null 2>&1 || got=$?

  if [ "$got" -ne 0 ] &&
     ! grep -Eq '^(workflow run|issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
    record "$name" true
  else
    record "$name" false "live authority failure was accepted (exit ${got})"
  fi
  rm -rf "$temp"
}

if [ ! -x "$collector" ]; then
  echo "FAIL — collector does not exist or is not executable: ${collector}" >&2
  exit 1
fi

run_case "exact first-attempt run writes canonical receipt" success 0
run_case "older runs appear before the exact run" old_runs_then_exact 0
for state in foreign_repository foreign_workflow missing_ref foreign_sha foreign_run_sha foreign_run_ref \
  foreign_run_workflow rerun missing_job extra_job red_job skipped_job cancelled_job nonterminal red_run \
  missing_fresh missing_restored unsupported_elixir_11_17 unsupported_elixir_1_170 unsupported_otp_127 \
  bad_local_authority missing_cache stale_rebuild red_verdict \
  incident_changed timeout api_failure watch_failure; do
  run_case "$state fails closed" "$state" 1
done

while IFS=$'\t' read -r name filter; do
  verify_mutation_case "$name" "$filter"
done <<'MUTATIONS'
created_at mutation fails closed	.created_at = "2026-09-09T12:00:02Z"
schema version mutation fails closed	.schema_version = 2
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
extra census key fails closed	.local_authorities.census.extra = true
extra live-truth key fails closed	.local_authorities.live_truth.extra = true
MUTATIONS

if grep -Eq 'contains\("1\.17"\)|contains\("27"\)' "$collector"; then
  record "receipt validation has no substring toolchain fallback" false "found contains() version classification"
else
  record "receipt validation has no substring toolchain fallback" true
fi

verify_live_state_case "fresh incident drift fails closed" incident_verify_changed
verify_live_state_case "local validator failure fails closed" local_validator_failure

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
    [ "$state" != timeout ] || { printf '[]\n'; exit; }
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
  "run watch") [ "$state" != watch_failure ] || exit 42 ;;
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
      jobs='[{"databaseId":1,"name":"Compat Matrix (1.15, 26)","status":"completed","conclusion":"success"},{"databaseId":2,"name":"Compat Matrix (1.16, 26)","status":"completed","conclusion":"success"},{"databaseId":3,"name":"Compat Matrix (1.17, 27)","status":"completed","conclusion":"success"},{"databaseId":4,"name":"Compat Matrix (1.18, 27)","status":"completed","conclusion":"success"},{"databaseId":5,"name":"Compat Matrix (1.18, 28)","status":"completed","conclusion":"success"},{"databaseId":6,"name":"Dialyzer","status":"completed","conclusion":"success"},{"databaseId":7,"name":"GCS Soak (real bucket)","status":"completed","conclusion":"success"},{"databaseId":8,"name":"Package Consumer GCS Live Proof","status":"completed","conclusion":"success"},{"databaseId":9,"name":"Nightly Summary","status":"completed","conclusion":"success"},{"databaseId":10,"name":"Nightly Incident Lifecycle","status":"completed","conclusion":"success"}]'
      [ "$state" != missing_job ] || jobs="$(jq 'del(.[0])' <<<"$jobs")"
      [ "$state" != extra_job ] || jobs="$(jq '. + [{databaseId:11,name:"Unexpected",status:"completed",conclusion:"success"}]' <<<"$jobs")"
      [ "$state" != red_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="failure" else . end)' <<<"$jobs")"
      [ "$state" != skipped_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="skipped" else . end)' <<<"$jobs")"
      [ "$state" != cancelled_job ] || jobs="$(jq 'map(if .name == "Dialyzer" then .conclusion="cancelled" else . end)' <<<"$jobs")"
      attempt=1; status=completed; conclusion=success
      [ "$state" != rerun ] || attempt=2
      [ "$state" != nonterminal ] || status=in_progress
      [ "$state" != red_run ] || conclusion=failure
      jq -cn --arg sha "$sha" --arg ref "$ref" --arg created "$created" --argjson jobs "$jobs" --argjson attempt "$attempt" --arg status "$status" --arg conclusion "$conclusion" '{attempt:$attempt,conclusion:$conclusion,createdAt:$created,databaseId:9001,event:"workflow_dispatch",headBranch:$ref,headSha:$sha,jobs:$jobs,status:$status,url:"https://github.test/runs/9001",workflowName:"Nightly"}'
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
