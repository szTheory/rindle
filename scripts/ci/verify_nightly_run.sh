#!/usr/bin/env bash
# Dispatch and verify one exact-subject diagnostic Nightly run.
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: verify_nightly_run.sh preflight|dispatch-and-record|verify-receipt' \
    '  --repo OWNER/REPO --workflow FILE --ref REMOTE_REF --expected-sha SHA' \
    '  [--receipt PATH] [--poll-seconds N] [--timeout-seconds N]' >&2
}

die() {
  echo "[verify-nightly-run] ERROR: $*" >&2
  exit 1
}

mode="${1:-}"
[ -n "$mode" ] || { usage; exit 64; }
shift

repo=""
workflow=""
remote_ref=""
expected_sha=""
receipt=""
poll_seconds=15
timeout_seconds=3600

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --workflow) workflow="${2:-}"; shift 2 ;;
    --ref) remote_ref="${2:-}"; shift 2 ;;
    --expected-sha) expected_sha="${2:-}"; shift 2 ;;
    --receipt) receipt="${2:-}"; shift 2 ;;
    --poll-seconds) poll_seconds="${2:-}"; shift 2 ;;
    --timeout-seconds) timeout_seconds="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v gh >/dev/null 2>&1 || die "gh is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid --repo"
[[ "$workflow" =~ ^[A-Za-z0-9_.-]+\.ya?ml$ ]] || die "invalid --workflow"
[[ "$remote_ref" =~ ^[A-Za-z0-9._/-]+$ ]] || die "invalid --ref"
[[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid --expected-sha"
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || die "invalid --poll-seconds"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || die "invalid --timeout-seconds"
case "$mode" in
  preflight) ;;
  dispatch-and-record|verify-receipt) [ -n "$receipt" ] || die "--receipt is required" ;;
  *) die "unknown mode: $mode" ;;
esac

canonical_incidents() {
  gh issue list --repo "$repo" --state open --label nightly-failure --limit 100 \
    --json number,title,body,comments,updatedAt,url |
    jq -cS 'sort_by(.number)'
}

preflight_json() {
  local repo_json workflow_yaml ref_json actual_repo actual_sha
  repo_json="$(gh repo view "$repo" --json nameWithOwner)" || die "repository lookup failed"
  actual_repo="$(jq -er '.nameWithOwner' <<<"$repo_json")" || die "repository lookup was malformed"
  [ "$actual_repo" = "$repo" ] || die "repository identity mismatch"

  workflow_yaml="$(gh workflow view "$workflow" --repo "$repo" --yaml)" || die "workflow lookup failed"
  grep -Eq '^name:[[:space:]]*Nightly[[:space:]]*$' <<<"$workflow_yaml" || die "workflow name mismatch"
  grep -Eq 'workflow_dispatch:' <<<"$workflow_yaml" || die "workflow lacks workflow_dispatch"

  ref_json="$(gh api "repos/${repo}/git/ref/heads/${remote_ref}")" || die "remote ref lookup failed"
  actual_sha="$(jq -er --arg ref "refs/heads/${remote_ref}" 'select(.ref == $ref) | .object.sha' <<<"$ref_json")" ||
    die "remote ref identity is malformed"
  [ "$actual_sha" = "$expected_sha" ] || die "remote ref SHA mismatch"
  jq -cnS --arg repository "$repo" --arg workflow "$workflow" --arg remote_ref "$remote_ref" \
    --arg subject_sha "$expected_sha" \
    '{repository:$repository,workflow:$workflow,remote_ref:$remote_ref,subject_sha:$subject_sha,status:"pass"}'
}

expected_job_names_json() {
  printf '%s\n' '["Compat Matrix (1.15, 26)","Compat Matrix (1.16, 26)","Compat Matrix (1.17, 27)","Compat Matrix (1.18, 27)","Compat Matrix (1.18, 28)","Dialyzer","GCS Soak (real bucket)","Nightly Incident Lifecycle","Nightly Summary","Package Consumer GCS Live Proof"]'
}

validate_run_json() {
  local run_json="$1" expected_jobs
  expected_jobs="$(expected_job_names_json)"
  jq -e --arg repo "$repo" --arg workflow "$workflow" --arg ref "$remote_ref" \
    --arg sha "$expected_sha" --argjson expected_jobs "$expected_jobs" '
      .workflowName == "Nightly" and .event == "workflow_dispatch" and
      .headBranch == $ref and .headSha == $sha and .attempt == 1 and
      .status == "completed" and .conclusion == "success" and
      (.databaseId | type == "number") and
      (.jobs | type == "array") and
      ([.jobs[].name] | sort) == $expected_jobs and
      (all(.jobs[]; .status == "completed" and .conclusion == "success" and
        (.databaseId | type == "number")))
    ' <<<"$run_json" >/dev/null || die "run identity, terminal state, or exact job set is not qualifying"
}

parse_log_evidence() {
  local logs="$1" resolved_elixir resolved_otp cache_key fresh_builds fresh_runs restored_runs stale_rebuilds verdict
  fresh_builds="$(grep -c 'nightly-dialyzer mode=fresh action=build-plt' <<<"$logs" || true)"
  fresh_runs="$(grep -c 'nightly-dialyzer mode=fresh attempt=1 action=analyze' <<<"$logs" || true)"
  restored_runs="$(grep -c 'nightly-dialyzer mode=restored attempt=1 action=analyze' <<<"$logs" || true)"
  stale_rebuilds="$(grep -c 'fingerprint=old-plt recovery=rebuild-once' <<<"$logs" || true)"
  [ "$fresh_builds" -eq 1 ] && [ "$fresh_runs" -eq 1 ] || die "fresh Dialyzer evidence is incomplete"
  [ "$restored_runs" -eq 1 ] || die "restored Dialyzer evidence is incomplete"
  [ "$stale_rebuilds" -eq 0 ] || die "supported run contains an unexplained stale PLT rebuild"

  resolved_elixir="$(sed -nE 's/.*Resolved Elixir version:[[:space:]]*([^[:space:]]+).*/\1/p; s/.*Installing Elixir[[:space:]]+([^[:space:]]+).*/\1/p' <<<"$logs" | sort -u)"
  resolved_otp="$(sed -nE 's/.*Resolved OTP version:[[:space:]]*([^[:space:]]+).*/\1/p; s/.*Installing Erlang\/OTP[[:space:]]+([^[:space:]]+).*/\1/p' <<<"$logs" | sort -u)"
  [ "$(wc -l <<<"$resolved_elixir" | tr -d ' ')" -eq 1 ] && [[ "$resolved_elixir" =~ 1\.17 ]] || die "resolved Elixir 1.17 evidence is missing or ambiguous"
  [ "$(wc -l <<<"$resolved_otp" | tr -d ' ')" -eq 1 ] && [[ "$resolved_otp" =~ 27 ]] || die "resolved OTP 27 evidence is missing or ambiguous"

  cache_key="$(sed -nE 's/.*(plt-v3-[^[:space:]]+).*/\1/p' <<<"$logs" | sort -u)"
  [ "$(wc -l <<<"$cache_key" | tr -d ' ')" -eq 1 ] && [[ "$cache_key" == *otp* ]] && [[ "$cache_key" == *elixir* ]] ||
    die "exact PLT cache identity is missing or ambiguous"
  [[ "$cache_key" == *"$resolved_otp"* ]] || die "PLT cache key omits resolved OTP identity"
  [[ "$cache_key" == *"$resolved_elixir"* ]] || die "PLT cache key omits resolved Elixir identity"

  verdict="$(sed -nE 's/.*verdict=(green|red).*/\1/p; s/.*test "(green|red)" = "green".*/\1/p' <<<"$logs" | sort -u)"
  [ "$verdict" = green ] || die "strict Nightly verdict is not uniquely green"

  jq -cnS --arg requested_elixir "1.17" --arg requested_otp "27" \
    --arg resolved_elixir "$resolved_elixir" --arg resolved_otp "$resolved_otp" \
    --arg cache_key "$cache_key" --argjson stale_rebuilds "$stale_rebuilds" \
    '{requested_elixir:$requested_elixir,requested_otp:$requested_otp,resolved_elixir:$resolved_elixir,resolved_otp:$resolved_otp,fresh:{status:"pass",builds:1,analyses:1},restored:{status:"pass",analyses:1},cache_key:$cache_key,stale_rebuilds:$stale_rebuilds}'
}

job_logs() {
  local run_id="$1" run_json="$2" job_name="$3" job_id
  job_id="$(jq -er --arg name "$job_name" '.jobs[] | select(.name == $name) | .databaseId' <<<"$run_json")" ||
    die "missing job ID for ${job_name}"
  gh run view "$run_id" --repo "$repo" --job "$job_id" --log ||
    die "${job_name} log lookup failed"
}

validate_local_authorities() {
  local value="${NIGHTLY_LOCAL_AUTHORITIES_JSON:-}"
  jq -e '
    type == "object" and (keys | sort) == ["census","live_truth"] and
    .census.status == "pass" and .live_truth.status == "pass"
  ' <<<"$value" >/dev/null || die "NIGHTLY_LOCAL_AUTHORITIES_JSON lacks green census/live-truth authority"
  jq -cS . <<<"$value"
}

verify_receipt_shape() {
  local path="$1"
  [ -s "$path" ] || die "receipt is missing or empty: $path"
  jq -e --arg repo "$repo" --arg workflow "$workflow" --arg ref "$remote_ref" --arg sha "$expected_sha" '
    .schema_version == 1 and .repository == $repo and .workflow == $workflow and
    .event == "workflow_dispatch" and .subject_sha == $sha and .remote_ref == $ref and
    (.run_id | type == "number") and .run_attempt == 1 and .conclusion == "success" and
    (.created_at | type == "string" and fromdateiso8601 >= 0) and
    (.jobs | type == "array" and length == 10 and all(.[]; .status == "completed" and .conclusion == "success")) and
    .dialyzer.requested_elixir == "1.17" and .dialyzer.requested_otp == "27" and
    (.dialyzer.resolved_elixir | contains("1.17")) and (.dialyzer.resolved_otp | contains("27")) and
    .dialyzer.fresh.status == "pass" and .dialyzer.restored.status == "pass" and
    (.dialyzer.cache_key | startswith("plt-v3-")) and .dialyzer.stale_rebuilds == 0 and
    .strict_verdict.verdict == "green" and
    .incident_snapshot_before == .incident_snapshot_after and
    .local_authorities.census.status == "pass" and .local_authorities.live_truth.status == "pass"
  ' "$path" >/dev/null || die "receipt schema or evidence is invalid"
}

if [ "$mode" = preflight ]; then
  preflight_json
  exit 0
fi

if [ "$mode" = verify-receipt ]; then
  preflight_json >/dev/null
  verify_receipt_shape "$receipt"
  run_id="$(jq -er '.run_id' "$receipt")"
  live_run="$(gh run view "$run_id" --repo "$repo" --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" || die "run verification lookup failed"
  validate_run_json "$live_run"
  [ "$(jq -r '.run_id' "$receipt")" = "$(jq -r '.databaseId' <<<"$live_run")" ] || die "receipt run ID differs from GitHub"
  live_dialyzer_logs="$(job_logs "$run_id" "$live_run" "Dialyzer")"
  live_summary_logs="$(job_logs "$run_id" "$live_run" "Nightly Summary")"
  live_dialyzer="$(parse_log_evidence "${live_dialyzer_logs}"$'\n'"${live_summary_logs}")"
  jq -e --argjson live "$live_dialyzer" '.dialyzer == $live' "$receipt" >/dev/null || die "receipt Dialyzer evidence differs from GitHub"
  echo "Nightly receipt valid for ${expected_sha} (run ${run_id}, attempt 1)"
  exit 0
fi

cleanup_paths=()
cleanup() {
  local path
  for path in "${cleanup_paths[@]}"; do rm -f -- "$path"; done
}
trap cleanup EXIT
rm -f -- "$receipt"
preflight="$(preflight_json)"
incident_before="$(canonical_incidents)" || die "incident snapshot before dispatch failed"
created_after="${NIGHTLY_NOW:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

gh workflow run "$workflow" --repo "$repo" --ref "$remote_ref" || die "workflow dispatch failed"
deadline=$(( $(date +%s) + timeout_seconds ))
run_id=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  runs="$(gh run list --repo "$repo" --workflow "$workflow" --event workflow_dispatch \
    --branch "$remote_ref" --limit 20 \
    --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,status,url,workflowName)" || die "run listing failed"
  matches="$(jq -c --arg sha "$expected_sha" --arg ref "$remote_ref" --arg boundary "$created_after" '
    [.[] | select(.workflowName == "Nightly" and .event == "workflow_dispatch" and
      .headBranch == $ref and .headSha == $sha and .createdAt >= $boundary)]
  ' <<<"$runs")" || die "run listing was malformed"
  match_count="$(jq 'length' <<<"$matches")"
  if [ "$match_count" -eq 1 ]; then
    run_id="$(jq -r '.[0].databaseId' <<<"$matches")"
    break
  fi
  if [ "$(jq 'length' <<<"$runs")" -gt 0 ] && [ "$match_count" -eq 0 ]; then
    die "new diagnostic run has foreign workflow/ref/SHA identity"
  fi
  [ "$poll_seconds" -eq 0 ] || sleep "$poll_seconds"
done
[ -n "$run_id" ] || die "timed out waiting for exact diagnostic run"

gh run watch "$run_id" --repo "$repo" --interval "$poll_seconds" || die "GitHub run watch failed"
run_json="$(gh run view "$run_id" --repo "$repo" --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" ||
  die "run detail lookup failed"
validate_run_json "$run_json"
dialyzer_logs="$(job_logs "$run_id" "$run_json" "Dialyzer")"
summary_logs="$(job_logs "$run_id" "$run_json" "Nightly Summary")"
dialyzer="$(parse_log_evidence "${dialyzer_logs}"$'\n'"${summary_logs}")"
local_authorities="$(validate_local_authorities)"
incident_after="$(canonical_incidents)" || die "incident snapshot after dispatch failed"
[ "$incident_before" = "$incident_after" ] || die "workflow_dispatch changed the nightly-failure incident"

temp_receipt="$(mktemp "${TMPDIR:-/tmp}/nightly-receipt.XXXXXX")"
cleanup_paths+=("$temp_receipt")
jq -nS \
  --arg repository "$repo" --arg workflow "$workflow" --arg event workflow_dispatch \
  --arg subject_sha "$expected_sha" --arg remote_ref "$remote_ref" \
  --argjson run "$run_json" --argjson dialyzer "$dialyzer" \
  --argjson before "$incident_before" --argjson after "$incident_after" \
  --argjson local_authorities "$local_authorities" --argjson preflight "$preflight" '
    {schema_version:1,repository:$repository,workflow:$workflow,event:$event,
     subject_sha:$subject_sha,remote_ref:$remote_ref,run_id:$run.databaseId,
     run_attempt:$run.attempt,conclusion:$run.conclusion,created_at:$run.createdAt,
     jobs:($run.jobs | sort_by(.name) | map({id:.databaseId,name,status,conclusion})),
     dialyzer:$dialyzer,strict_verdict:{verdict:"green",summary_job:"Nightly Summary"},
     incident_snapshot_before:$before,incident_snapshot_after:$after,
     local_authorities:$local_authorities,preflight:$preflight}
  ' >"$temp_receipt"
verify_receipt_shape "$temp_receipt"
mkdir -p "$(dirname "$receipt")"
mv "$temp_receipt" "$receipt"
cleanup_paths=()
echo "Recorded exact Nightly evidence for ${expected_sha} in ${receipt}"
