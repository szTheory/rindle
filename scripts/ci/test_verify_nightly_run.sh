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

  local_authorities='{"census":{"status":"pass"},"live_truth":{"status":"pass"}}'
  [ "$state" != bad_local_authority ] || local_authorities='{"census":{"status":"fail"},"live_truth":{"status":"pass"}}'
  PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
    FAKE_GH_STATE="$state" NIGHTLY_LOCAL_AUTHORITIES_JSON="$local_authorities" \
    NIGHTLY_NOW=2026-09-09T12:00:00Z \
    bash "$collector" dispatch-and-record --repo szTheory/rindle --workflow nightly.yml \
      --ref phase-133-evidence-aaaaaaaaaaaa --expected-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
      --receipt "${temp}/receipt.json" --poll-seconds 0 --timeout-seconds 2 >/dev/null 2>&1 || got=$?

  if [ "$state" = success ] && [ "$got" -eq 0 ]; then
    PATH="${temp}/bin:${PATH}" FAKE_GH_LOG="${temp}/calls" FAKE_GH_COUNT_FILE="${temp}/count" \
      FAKE_GH_STATE=success bash "$collector" verify-receipt --repo szTheory/rindle --workflow nightly.yml \
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
       ! grep -Eq '^(issue (create|comment|close|edit|delete)|run (cancel|rerun|delete))' "${temp}/calls"; then
      record "success argv is one dispatch plus read-only inspection" true
    else
      record "success argv is one dispatch plus read-only inspection" false "unsafe or missing call"
    fi
  fi
  rm -rf "$temp"
}

if [ ! -x "$collector" ]; then
  echo "FAIL — collector does not exist or is not executable: ${collector}" >&2
  exit 1
fi

run_case "exact first-attempt run writes canonical receipt" success 0
for state in foreign_repository foreign_workflow missing_ref foreign_sha foreign_run_sha foreign_run_ref \
  foreign_run_workflow rerun missing_job extra_job red_job skipped_job cancelled_job nonterminal red_run \
  missing_fresh missing_restored unsupported_toolchain bad_local_authority missing_cache stale_rebuild red_verdict \
  incident_changed timeout api_failure watch_failure; do
  run_case "$state fails closed" "$state" 1
done

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
        [ "$state" = unsupported_toolchain ] || printf '%s\n' 'Dialyzer\tSet up Elixir\tResolved Elixir version: 1.17.3' 'Dialyzer\tSet up Elixir\tResolved OTP version: 27.3.4.17'
        [ "$state" = missing_fresh ] || printf '%s\n' 'Dialyzer\tDialyzer (fresh PLT)\tnightly-dialyzer mode=fresh action=build-plt' 'Dialyzer\tDialyzer (fresh PLT)\tnightly-dialyzer mode=fresh attempt=1 action=analyze'
        [ "$state" = missing_cache ] || printf '%s\n' 'Dialyzer\tSave PLT cache\tCache saved with key: plt-v3-Linux-X64-otp27.3.4.17-elixir1.17.3-inputhash'
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
    jq -cn --arg body "$body" '[{number:88,title:"Nightly CI failure",body:$body,comments:[],updatedAt:"2026-09-09T11:00:00Z",url:"https://github.test/issues/88"}]'
    ;;
  *) echo "unexpected fake gh call: $*" >&2; exit 43 ;;
esac
# END EMBEDDED FAKE GH
