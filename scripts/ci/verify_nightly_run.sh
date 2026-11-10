#!/usr/bin/env bash
# Dispatch and verify one exact-subject diagnostic Nightly run, or verify one
# scheduled Nightly run on main read-only (verify-scheduled).
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: verify_nightly_run.sh preflight|dispatch-and-record|verify-receipt|verify-main-ci-receipt' \
    '  --repo OWNER/REPO --workflow FILE --ref REMOTE_REF --expected-sha SHA' \
    '  [--receipt PATH] [--poll-seconds N] [--timeout-seconds N]' \
    '   or: verify_nightly_run.sh verify-scheduled|capture-scheduled-and-record|verify-scheduled-receipt' \
    '  --repo OWNER/REPO --workflow FILE --expected-sha SHA --receipt PATH [--run-id ID]' \
    '  scheduled reconciliation modes also require --source-root PATH --evidence-root PATH' >&2
}

die() {
  echo "[verify-nightly-run] ERROR: $*" >&2
  exit 1
}

github_rate_limit_error() {
  local error_file="$1"
  LC_ALL=C grep -Eiq '(^|[^[:alnum:]_])(API rate limit exceeded|secondary rate limit)([^[:alnum:]_]|$)' "$error_file"
}

read_with_rate_limit_recovery() {
  local output_file error_file status
  output_file="$(mktemp "${TMPDIR:-/tmp}/nightly-read-output.XXXXXX")"
  error_file="$(mktemp "${TMPDIR:-/tmp}/nightly-read-error.XXXXXX")"

  while true; do
    if "$@" >"$output_file" 2>"$error_file"; then
      cat "$output_file"
      rm -f -- "$output_file" "$error_file"
      return 0
    else
      status=$?
    fi

    if ! github_rate_limit_error "$error_file" || [ "$(date +%s)" -ge "$deadline" ]; then
      rm -f -- "$output_file" "$error_file"
      return "$status"
    fi
    [ "$poll_seconds" -eq 0 ] || sleep "$poll_seconds"
  done
}

mode="${1:-}"
[ -n "$mode" ] || { usage; exit 64; }
shift

repo=""
workflow="nightly.yml"
remote_ref="main"
expected_sha=""
receipt=""
run_id_arg=""
source_root=""
evidence_root=""
poll_seconds=15
timeout_seconds=3600

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --workflow) workflow="${2:-}"; shift 2 ;;
    --ref) remote_ref="${2:-}"; shift 2 ;;
    --expected-sha) expected_sha="${2:-}"; shift 2 ;;
    --receipt) receipt="${2:-}"; shift 2 ;;
    --run-id) run_id_arg="${2:-}"; shift 2 ;;
    --source-root) source_root="${2:-}"; shift 2 ;;
    --evidence-root) evidence_root="${2:-}"; shift 2 ;;
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
if [ "$mode" = verify-scheduled ]; then
  [ "$remote_ref" = main ] || die "verify-scheduled reads main only"
fi
case "$mode" in
  capture-scheduled-and-record|verify-scheduled-receipt)
    [ "$remote_ref" = main ] || die "scheduled modes read main only"
    [ "$workflow" = nightly.yml ] || die "Plan 278 accepts only the scheduled nightly.yml workflow"
    [ -n "$source_root" ] && [ -n "$evidence_root" ] || die "scheduled modes require --source-root and --evidence-root"
    ;;
esac
[[ "$remote_ref" =~ ^[A-Za-z0-9._/-]+$ ]] || die "invalid --ref"
[ -z "$run_id_arg" ] || [[ "$run_id_arg" =~ ^[1-9][0-9]{0,19}$ ]] || die "invalid --run-id"
[[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid --expected-sha"
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || die "invalid --poll-seconds"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || die "invalid --timeout-seconds"
case "$mode" in
  preflight) ;;
  dispatch-and-record|verify-receipt|verify-scheduled|verify-main-ci-receipt|capture-scheduled-and-record|verify-scheduled-receipt) [ -n "$receipt" ] || die "--receipt is required" ;;
  *) die "unknown mode: $mode" ;;
esac

canonical_incidents() {
  local recover="${1:-false}" incidents
  if [ "$recover" = true ]; then
    incidents="$(read_with_rate_limit_recovery gh issue list --repo "$repo" --state all \
      --label nightly-failure --limit 100 --json number,title,body,comments,updatedAt,url,state)" ||
      return $?
  else
    incidents="$(gh issue list --repo "$repo" --state all --label nightly-failure --limit 100 \
      --json number,title,body,comments,updatedAt,url,state)" || return $?
  fi
  jq -cS 'map(del(.state)) | sort_by(.number)' <<<"$incidents"
}

matching_run_ids() {
  local recover="${1:-false}" runs
  if [ "$recover" = true ]; then
    runs="$(read_with_rate_limit_recovery gh run list --repo "$repo" --workflow "$workflow" \
      --event workflow_dispatch --branch "$remote_ref" --limit 20 \
      --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,status,url,workflowName)" ||
      die "run listing failed after bounded observation"
  else
    runs="$(gh run list --repo "$repo" --workflow "$workflow" --event workflow_dispatch \
      --branch "$remote_ref" --limit 20 \
      --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,status,url,workflowName)" ||
      die "run listing failed"
  fi
  jq -e '
    type == "array" and
    ([.[].databaseId] | unique | length) == length and
    all(.[];
      type == "object" and
      keys == ["attempt","conclusion","createdAt","databaseId","event","headBranch","headSha","status","url","workflowName"] and
      (.attempt as $attempt | ($attempt | type) == "number" and $attempt >= 1 and ($attempt | floor) == $attempt) and
      (.conclusion == null or (.conclusion | type) == "string") and
      (.createdAt | type == "string" and fromdateiso8601 >= 0) and
      (.databaseId as $id | ($id | type) == "number" and $id >= 1 and ($id | floor) == $id) and
      (.event | type) == "string" and
      (.headBranch | type) == "string" and
      (.headSha | type) == "string" and
      (.status | type) == "string" and
      (.url | type) == "string" and
      (.workflowName | type) == "string")
  ' <<<"$runs" >/dev/null || die "run listing was malformed or contained duplicate/non-integer IDs"
  jq -c --arg sha "$expected_sha" --arg ref "$remote_ref" '
    [.[] | select(.workflowName == "Nightly" and .event == "workflow_dispatch" and
      .headBranch == $ref and .headSha == $sha) | .databaseId] | sort
  ' <<<"$runs" || die "run listing was malformed"
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
  printf '%s\n' '["Compat Matrix (1.15, 26)","Compat Matrix (1.16, 26)","Compat Matrix (1.17, 27)","Compat Matrix (1.18, 27)","Compat Matrix (1.18, 28)","Dialyzer","GCS Soak (real bucket)","Nightly Incident Lifecycle","Nightly Summary","Package Consumer GCS Live Proof","Persist Nightly Incident Verdict"]'
}

validate_run_json() {
  local run_json="$1" expected_jobs
  expected_jobs="$(expected_job_names_json)"
  jq -e --arg repo "$repo" --arg workflow "$workflow" --arg ref "$remote_ref" \
    --arg sha "$expected_sha" --argjson expected_jobs "$expected_jobs" '
      (.jobs | map({databaseId,name,status,conclusion})) as $jobs |
      (keys == ["attempt","conclusion","createdAt","databaseId","event","headBranch","headSha","jobs","status","url","workflowName"]) and
      .workflowName == "Nightly" and .event == "workflow_dispatch" and
      .headBranch == $ref and .headSha == $sha and .attempt == 1 and
      .status == "completed" and .conclusion == "success" and
      (.databaseId | type == "number") and
      (.createdAt | type == "string" and fromdateiso8601 >= 0) and
      (.url | type == "string" and length > 0) and
      (.jobs | type == "array") and
      (all($jobs[]; keys == ["conclusion","databaseId","name","status"])) and
      ([$jobs[].name] | sort) == $expected_jobs and
      ([$jobs[].databaseId] | unique | length) == ($expected_jobs | length) and
      (all($jobs[];
        .status == "completed" and (.databaseId | type == "number") and
        (if (.name == "Nightly Incident Lifecycle" or .name == "Persist Nightly Incident Verdict")
         then .conclusion == "skipped"
         else .conclusion == "success"
         end)))
    ' <<<"$run_json" >/dev/null || die "run identity, terminal state, or exact job set is not qualifying"
}

parse_supported_elixir_version() {
  local value="$1" major minor
  if [[ "$value" =~ ^v?([0-9]+)\.([0-9]+)(\.[0-9]+)*(-otp-[0-9]+(\.[0-9]+)*)?$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    [ "$major" = 1 ] && [ "$minor" = 17 ] && printf '%s\n' "$value"
    return
  fi
  return 1
}

parse_supported_otp_version() {
  local value="$1" major
  if [[ "$value" =~ ^(OTP-)?([0-9]+)(\.[0-9]+)*$ ]]; then
    major="${BASH_REMATCH[2]}"
    [ "$major" = 27 ] && printf '%s\n' "$value"
    return
  fi
  return 1
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
  [ -n "$resolved_elixir" ] && [ "$(printf '%s\n' "$resolved_elixir" | wc -l | tr -d ' ')" -eq 1 ] ||
    die "resolved Elixir evidence is missing or ambiguous"
  parse_supported_elixir_version "$resolved_elixir" >/dev/null ||
    die "resolved Elixir toolchain is unsupported; expected 1.17.x"
  [ -n "$resolved_otp" ] && [ "$(printf '%s\n' "$resolved_otp" | wc -l | tr -d ' ')" -eq 1 ] ||
    die "resolved OTP evidence is missing or ambiguous"
  parse_supported_otp_version "$resolved_otp" >/dev/null ||
    die "resolved OTP toolchain is unsupported; expected 27.x"

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
  local run_id="$1" run_json="$2" job_name="$3" recover="${4:-false}" job_id
  job_id="$(jq -er --arg name "$job_name" '.jobs[] | select(.name == $name) | .databaseId' <<<"$run_json")" ||
    die "missing job ID for ${job_name}"
  if [ "$recover" = true ]; then
    read_with_rate_limit_recovery gh run view "$run_id" --repo "$repo" --job "$job_id" --log ||
      die "${job_name} log lookup failed after bounded observation"
  else
    gh run view "$run_id" --repo "$repo" --job "$job_id" --log ||
      die "${job_name} log lookup failed"
  fi
}

ledger_path='.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json'

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

materialize_ledger_object() {
  local project_root="$1" commit="$2" path="$3" expected_blob="$4" output="$5" actual_blob actual_sha
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "ledger commit identity is malformed"
  [ "$path" = "$ledger_path" ] || die "ledger path identity is not repository-owned"
  [[ "$expected_blob" =~ ^[0-9a-f]{40}$ ]] || die "ledger blob identity is malformed"
  actual_blob="$(git -C "$project_root" rev-parse "${commit}:${path}")" ||
    die "ledger path is absent from recorded commit"
  [ "$actual_blob" = "$expected_blob" ] || die "ledger blob differs from recorded commit:path"
  git -C "$project_root" show "${commit}:${path}" >"$output" ||
    die "could not materialize recorded ledger object"
  [ -s "$output" ] || die "materialized ledger object is empty"
  actual_sha="$(sha256_file "$output")" || die "could not hash materialized ledger object"
  printf '%s\n' "$actual_sha"
}

resolve_ledger_object() {
  local project_root="$1" output="$2" status commit blob digest
  status="$(git -C "$project_root" status --porcelain --untracked-files=all -- "$ledger_path")" ||
    die "could not inspect census ledger status"
  [ -z "$status" ] || die "census ledger must be tracked and clean for collection"
  git -C "$project_root" ls-files --error-unmatch -- "$ledger_path" >/dev/null 2>&1 ||
    die "census ledger is not tracked"
  commit="$(git -C "$project_root" log -1 --format=%H -- "$ledger_path")" ||
    die "could not resolve census ledger commit"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "census ledger has no containing commit"
  blob="$(git -C "$project_root" rev-parse "${commit}:${ledger_path}")" ||
    die "could not resolve census ledger blob"
  digest="$(materialize_ledger_object "$project_root" "$commit" "$ledger_path" "$blob" "$output")"
  jq -cnS --arg ledger_path "$ledger_path" --arg ledger_sha256 "$digest" \
    --arg ledger_blob "$blob" --arg ledger_commit "$commit" \
    '{ledger_path:$ledger_path,ledger_sha256:$ledger_sha256,ledger_blob:$ledger_blob,ledger_commit:$ledger_commit}'
}

verify_receipt_shape() {
  local path="$1" expected_jobs resolved_elixir resolved_otp cache_key
  expected_jobs="$(expected_job_names_json)"
  [ -s "$path" ] || die "receipt is missing or empty: $path"
  jq -e --arg repo "$repo" --arg workflow "$workflow" --arg ref "$remote_ref" --arg sha "$expected_sha" \
    --argjson expected_jobs "$expected_jobs" '
    def exact_keys($expected): (type == "object") and ((keys) == ($expected | sort));
    def valid_reactions:
      type == "array" and all(.[];
        exact_keys(["content","users"]) and
        (.content | type == "string") and
        (.users | exact_keys(["totalCount"])) and (.users.totalCount | type == "number"));
    def valid_comments:
      type == "array" and all(.[];
        exact_keys(["author","authorAssociation","body","createdAt","id","includesCreatedEdit","isMinimized","minimizedReason","reactionGroups","url","viewerDidAuthor"]) and
        (.author | exact_keys(["login"])) and (.author.login | type == "string") and
        (.authorAssociation | type == "string") and (.body | type == "string") and
        (.createdAt | type == "string" and fromdateiso8601 >= 0) and (.id | type == "string") and
        (.includesCreatedEdit | type == "boolean") and (.isMinimized | type == "boolean") and
        (.minimizedReason | type == "string") and (.reactionGroups | valid_reactions) and
        (.url | type == "string") and (.viewerDidAuthor | type == "boolean"));
    def valid_incidents:
      type == "array" and
      ([.[].number] | unique | length) == length and
      all(.[];
        exact_keys(["body","comments","number","title","updatedAt","url"]) and
        (.number | type == "number") and (.title | type == "string") and (.body | type == "string") and
        (.comments | valid_comments) and (.updatedAt | type == "string" and fromdateiso8601 >= 0) and
        (.url | type == "string"));

    exact_keys(["conclusion","created_at","dialyzer","event","incident_snapshot_after","incident_snapshot_before","jobs","local_authorities","preflight","remote_ref","repository","run_attempt","run_id","schema_version","strict_verdict","subject_sha","workflow"]) and
    .schema_version == 2 and .repository == $repo and .workflow == $workflow and
    .event == "workflow_dispatch" and .subject_sha == $sha and .remote_ref == $ref and
    (.run_id | type == "number") and .run_attempt == 1 and .conclusion == "success" and
    (.created_at | type == "string" and fromdateiso8601 >= 0) and
    (.jobs | type == "array" and length == 11 and
      [.[].name] == $expected_jobs and ([.[].id] | unique | length) == 11 and
      all(.[]; exact_keys(["conclusion","id","name","status"]) and (.id | type == "number") and
        (.name | type == "string") and .status == "completed" and
        (if (.name == "Nightly Incident Lifecycle" or .name == "Persist Nightly Incident Verdict")
         then .conclusion == "skipped"
         else .conclusion == "success"
         end))) and
    (.dialyzer | exact_keys(["cache_key","fresh","requested_elixir","requested_otp","resolved_elixir","resolved_otp","restored","stale_rebuilds"])) and
    .dialyzer.requested_elixir == "1.17" and .dialyzer.requested_otp == "27" and
    (.dialyzer.fresh | exact_keys(["analyses","builds","status"])) and
    .dialyzer.fresh == {analyses:1,builds:1,status:"pass"} and
    (.dialyzer.restored | exact_keys(["analyses","status"])) and
    .dialyzer.restored == {analyses:1,status:"pass"} and
    (.dialyzer.cache_key | startswith("plt-v3-")) and .dialyzer.stale_rebuilds == 0 and
    (.strict_verdict | exact_keys(["summary_job","verdict"])) and
    .strict_verdict == {summary_job:"Nightly Summary",verdict:"green"} and
    (.incident_snapshot_before | valid_incidents) and (.incident_snapshot_after | valid_incidents) and
    .incident_snapshot_before == .incident_snapshot_after and
    (.local_authorities | exact_keys(["census","live_truth"])) and
    (.local_authorities.census | exact_keys(["ledger_blob","ledger_commit","ledger_path","ledger_sha256","receipt","status","subject_sha"])) and
    .local_authorities.census.status == "pass" and
    .local_authorities.census.ledger_path == ".planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json" and
    (.local_authorities.census.ledger_sha256 | test("^[0-9a-f]{64}$")) and
    (.local_authorities.census.ledger_blob | test("^[0-9a-f]{40}$")) and
    (.local_authorities.census.ledger_commit | test("^[0-9a-f]{40}$")) and
    .local_authorities.census.subject_sha == $sha and
    (.local_authorities.census.receipt | type == "object") and
    (.local_authorities.live_truth | exact_keys(["model_sha256","status","subject_sha"])) and
    .local_authorities.live_truth.status == "pass" and
    .local_authorities.live_truth.subject_sha == $sha and
    (.local_authorities.live_truth.model_sha256 | test("^[0-9a-f]{64}$")) and
    (.preflight | exact_keys(["remote_ref","repository","status","subject_sha","workflow"]))
  ' "$path" >/dev/null || die "receipt schema or evidence is invalid"

  resolved_elixir="$(jq -er '.dialyzer.resolved_elixir | select(type == "string")' "$path")" ||
    die "receipt resolved Elixir evidence is malformed"
  parse_supported_elixir_version "$resolved_elixir" >/dev/null ||
    die "receipt resolved Elixir toolchain is unsupported; expected 1.17.x"
  resolved_otp="$(jq -er '.dialyzer.resolved_otp | select(type == "string")' "$path")" ||
    die "receipt resolved OTP evidence is malformed"
  parse_supported_otp_version "$resolved_otp" >/dev/null ||
    die "receipt resolved OTP toolchain is unsupported; expected 27.x"
  cache_key="$(jq -er '.dialyzer.cache_key | select(type == "string")' "$path")" ||
    die "receipt PLT cache identity is malformed"
  [[ "$cache_key" == *"$resolved_otp"* ]] || die "receipt PLT cache key omits resolved OTP identity"
  [[ "$cache_key" == *"$resolved_elixir"* ]] || die "receipt PLT cache key omits resolved Elixir identity"
}

expected_remote_from_live() {
  local preflight="$1" run_json="$2" dialyzer="$3"
  jq -cnS --arg repository "$repo" --arg workflow "$workflow" --arg event workflow_dispatch \
    --arg subject_sha "$expected_sha" --arg remote_ref "$remote_ref" \
    --argjson run "$run_json" --argjson dialyzer "$dialyzer" --argjson preflight "$preflight" '
      {repository:$repository,workflow:$workflow,event:$event,subject_sha:$subject_sha,
       remote_ref:$remote_ref,run_id:$run.databaseId,run_attempt:$run.attempt,
       conclusion:$run.conclusion,created_at:$run.createdAt,
       jobs:($run.jobs | sort_by(.name) | map({id:.databaseId,name,status,conclusion})),
       dialyzer:$dialyzer,strict_verdict:{verdict:"green",summary_job:"Nightly Summary"},
       preflight:$preflight}
    '
}

compare_exact_remote_receipt() {
  local path="$1" expected="$2"
  jq -e --argjson expected "$expected" '
    {repository,workflow,event,subject_sha,remote_ref,run_id,run_attempt,conclusion,created_at,
     jobs,dialyzer,strict_verdict,preflight} == $expected
  ' "$path" >/dev/null || die "receipt remote evidence differs from live reconstruction"
}

revalidate_local_authorities() {
  local recorded_census="${1:-}" project_root temp_root subject_root ledger_file census_receipt live_model
  local mix_executable authority_path ledger_identity ledger_digest census_json live_json model_digest authority_status=0 cleanup_status=0
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  mix_executable="$(command -v mix)" || die "mix is required for local authority revalidation"
  if [[ "$mix_executable" == */.asdf/shims/mix ]] && [ -x /opt/homebrew/bin/mix ]; then
    mix_executable=/opt/homebrew/bin/mix
  fi
  authority_path="$(dirname "$mix_executable"):${PATH}"
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/nightly-authority.XXXXXX")"
  subject_root="${temp_root}/subject"
  ledger_file="${temp_root}/ledger.json"
  census_receipt="${temp_root}/census.json"

  if [ -n "$recorded_census" ]; then
    ledger_identity="$(jq -ce '
      {ledger_path,ledger_sha256,ledger_blob,ledger_commit} |
      select(all(.[]; type == "string"))
    ' <<<"$recorded_census")" || die "recorded census ledger identity is malformed"
    ledger_digest="$(materialize_ledger_object "$project_root" \
      "$(jq -r '.ledger_commit' <<<"$ledger_identity")" \
      "$(jq -r '.ledger_path' <<<"$ledger_identity")" \
      "$(jq -r '.ledger_blob' <<<"$ledger_identity")" "$ledger_file")"
    [ "$ledger_digest" = "$(jq -r '.ledger_sha256' <<<"$ledger_identity")" ] ||
      die "materialized ledger SHA-256 differs from receipt"
  else
    ledger_identity="$(resolve_ledger_object "$project_root" "$ledger_file")"
  fi

  git -C "$project_root" worktree add --detach "$subject_root" "$expected_sha" >/dev/null 2>&1 || {
    rm -rf -- "$temp_root"
    die "could not materialize exact-subject authority worktree"
  }

  (
    cd "$subject_root"
    PATH="$authority_path" MIX_ENV=test MIX_DEPS_PATH="${project_root}/deps" MIX_BUILD_PATH="${project_root}/_build" \
      "$mix_executable" run --no-start --no-deps-check --no-compile scripts/maintainer/evidence_census.exs \
        --root . \
        --ledger "$ledger_file" \
        --output "$census_receipt" \
        --source-sha "$expected_sha" >/dev/null &&
    PATH="$authority_path" MIX_ENV=test MIX_DEPS_PATH="${project_root}/deps" MIX_BUILD_PATH="${project_root}/_build" \
      "$mix_executable" run --no-start --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs \
        --root . \
        --ledger "$ledger_file" \
        --receipt "$census_receipt" >/dev/null &&
    PATH="$authority_path" MIX_ENV=test MIX_DEPS_PATH="${project_root}/deps" MIX_BUILD_PATH="${project_root}/_build" \
      "$mix_executable" run --no-start --no-deps-check --no-compile -e \
        'Code.require_file("scripts/maintainer/validate_live_truth.exs"); Rindle.ValidateLiveTruth.run(["--root", ".", "--format", "json"])' >"$temp_root/live-truth.json"
  ) || authority_status=$?

  git -C "$project_root" worktree remove --force "$subject_root" >/dev/null 2>&1 || cleanup_status=$?
  [ "$cleanup_status" -eq 0 ] || {
    rm -rf -- "$temp_root"
    die "could not remove exact-subject authority worktree"
  }
  [ "$authority_status" -eq 0 ] || {
    rm -rf -- "$temp_root"
    die "exact-subject local authority revalidation failed"
  }
  census_json="$(jq -ceS 'select(type == "object")' "$census_receipt")" || {
    rm -rf -- "$temp_root"
    die "generated census receipt is malformed"
  }
  live_model="$(jq -ceS 'select(type == "object") | del(.authority_root)' "$temp_root/live-truth.json")" || {
    rm -rf -- "$temp_root"
    die "generated live-truth model is malformed"
  }
  live_json="${temp_root}/live-truth-canonical.json"
  printf '%s\n' "$live_model" >"$live_json"
  model_digest="$(sha256_file "$live_json")"

  jq -cnS --argjson ledger "$ledger_identity" --argjson receipt "$census_json" \
    --arg subject_sha "$expected_sha" --arg model_sha256 "$model_digest" '
      {census:($ledger + {status:"pass",subject_sha:$subject_sha,receipt:$receipt}),
       live_truth:{status:"pass",subject_sha:$subject_sha,model_sha256:$model_sha256}}
    '
  rm -rf -- "$temp_root"
}

compare_exact_local_and_incident_receipt() {
  local path="$1" incidents="$2" local_authorities="$3"
  jq -e --argjson incidents "$incidents" '
    def exact_keys($expected): (type == "object") and ((keys) == ($expected | sort));
    def valid_reactions:
      type == "array" and all(.[];
        exact_keys(["content","users"]) and
        (.content | type == "string") and
        (.users | exact_keys(["totalCount"])) and (.users.totalCount | type == "number"));
    def valid_comments:
      type == "array" and all(.[];
        exact_keys(["author","authorAssociation","body","createdAt","id","includesCreatedEdit","isMinimized","minimizedReason","reactionGroups","url","viewerDidAuthor"]) and
        (.author | exact_keys(["login"])) and (.author.login | type == "string") and
        (.authorAssociation | type == "string") and (.body | type == "string") and
        (.createdAt | type == "string" and fromdateiso8601 >= 0) and (.id | type == "string") and
        (.includesCreatedEdit | type == "boolean") and (.isMinimized | type == "boolean") and
        (.minimizedReason | type == "string") and (.reactionGroups | valid_reactions) and
        (.url | type == "string") and (.viewerDidAuthor | type == "boolean"));
    def valid_incidents:
      type == "array" and
      ([.[].number] | unique | length) == length and
      all(.[];
        exact_keys(["body","comments","number","title","updatedAt","url"]) and
        (.number | type == "number") and (.title | type == "string") and
        (.body | type == "string") and (.comments | valid_comments) and
        (.updatedAt | type == "string" and fromdateiso8601 >= 0) and (.url | type == "string"));
    def preserves_incident($recorded; $current):
      $current.number == $recorded.number and
      $current.title == $recorded.title and
      ($current.body | startswith($recorded.body)) and
      $current.url == $recorded.url and
      (($current.updatedAt | fromdateiso8601) >= ($recorded.updatedAt | fromdateiso8601)) and
      all($recorded.comments[];
        . as $comment | ($current.comments | index($comment)) != null);

    (.incident_snapshot_before == .incident_snapshot_after) and
    ($incidents | valid_incidents) and
    all(.incident_snapshot_after[];
      . as $recorded |
      any($incidents[]; .number == $recorded.number and .url == $recorded.url and preserves_incident($recorded; .)))
  ' "$path" >/dev/null || die "receipt incident history is missing or contradicts its durable snapshot"
  jq -e --argjson local "$local_authorities" '.local_authorities == $local' "$path" >/dev/null ||
    die "receipt local-authority evidence differs from exact-subject revalidation"
}

# verify-scheduled: read-only evidence for one completed attempt-1 scheduled
# Nightly run on main at the expected SHA. It records every job conclusion and
# the run's immutable incident-verdict artifact, and rejects any disagreement
# between the artifact's gating-need results and the observed job conclusions.
gating_need_jobs_json() {
  printf '%s\n' '{"compat-matrix":"Compat Matrix","dialyzer":"Dialyzer","gcs-soak":"GCS Soak (real bucket)","package-consumer-gcs-live":"Package Consumer GCS Live Proof"}'
}

verify_scheduled() {
  local runs candidates count run_id run_json artifact_dir artifact receipt_dir temp_receipt
  if [ -e "$receipt" ] || [ -L "$receipt" ]; then
    die "receipt destination already exists"
  fi
  runs="$(gh run list --repo "$repo" --workflow "$workflow" --event schedule --branch main \
    --commit "$expected_sha" --limit 100 \
    --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,status,url,workflowName)" ||
    die "scheduled run listing failed"
  candidates="$(jq -c --arg sha "$expected_sha" --arg pin "$run_id_arg" '
    [.[] | select(.workflowName == "Nightly" and .event == "schedule" and .headBranch == "main" and
      .headSha == $sha and .status == "completed" and
      ($pin == "" or (.databaseId | tostring) == $pin))]
  ' <<<"$runs")" || die "scheduled run listing was malformed"
  count="$(jq 'length' <<<"$candidates")"
  [ "$count" -ge 1 ] || die "no completed scheduled Nightly run on main for ${expected_sha}${run_id_arg:+ with run id ${run_id_arg}}"
  [ "$count" -eq 1 ] || die "ambiguous scheduled runs for ${expected_sha} ($(jq -r 'map(.databaseId) | join(",")' <<<"$candidates")); pass --run-id"
  jq -e '.[0].attempt == 1' <<<"$candidates" >/dev/null || die "scheduled run attempt is not 1; reruns do not qualify"
  run_id="$(jq -r '.[0].databaseId' <<<"$candidates")"

  run_json="$(gh run view "$run_id" --repo "$repo" \
    --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" ||
    die "scheduled run detail lookup failed"
  jq -e --argjson id "$run_id" --arg sha "$expected_sha" '
    .databaseId == $id and .workflowName == "Nightly" and .event == "schedule" and
    .headBranch == "main" and .headSha == $sha and .attempt == 1 and .status == "completed" and
    (.conclusion | type == "string") and (.jobs | type == "array" and length > 0) and
    all(.jobs[]; .status == "completed" and (.name | type == "string") and (.conclusion | type == "string"))
  ' <<<"$run_json" >/dev/null || die "scheduled run identity or terminal state differs from the listing"

  artifact_dir="$(mktemp -d "${TMPDIR:-/tmp}/nightly-verdict.XXXXXX")"
  gh run download "$run_id" --repo "$repo" --name "nightly-incident-verdict-${run_id}-1" --dir "$artifact_dir" >/dev/null 2>&1 || {
    rm -rf -- "$artifact_dir"
    die "verdict artifact nightly-incident-verdict-${run_id}-1 is missing"
  }
  artifact="$(jq -cS . "${artifact_dir}/nightly-incident-verdict.json" 2>/dev/null)" || {
    rm -rf -- "$artifact_dir"
    die "verdict artifact is unreadable"
  }
  rm -rf -- "$artifact_dir"
  jq -e --arg repo "$repo" --argjson id "$run_id" --arg sha "$expected_sha" --argjson needs "$(gating_need_jobs_json)" '
    .schema == "rindle-nightly-incident-verdict-v1" and .repository == $repo and
    .workflow_name == "Nightly" and .event == "schedule" and .run_id == $id and .run_attempt == 1 and
    .sha == $sha and .ref == "refs/heads/main" and
    (.verdict.verdict | IN("green", "red")) and
    ([.verdict.jobs[].name] | sort) == ($needs | keys)
  ' <<<"$artifact" >/dev/null || die "verdict artifact does not belong to scheduled run ${run_id} at ${expected_sha}"

  local need job_prefix observed recorded
  for need in $(jq -r 'keys[]' <<<"$(gating_need_jobs_json)"); do
    job_prefix="$(jq -r --arg n "$need" '.[$n]' <<<"$(gating_need_jobs_json)")"
    observed="$(jq -r --arg p "$job_prefix" '
      [.jobs[] | select(.name == $p or (.name | startswith($p + " ("))) | .conclusion] as $c |
      if ($c | length) == 0 then "missing"
      elif any($c[]; . == "failure") then "failure"
      elif any($c[]; . == "cancelled") then "cancelled"
      elif all($c[]; . == "skipped") then "skipped"
      elif all($c[]; IN("success", "skipped")) then "success"
      else "unknown" end
    ' <<<"$run_json")"
    recorded="$(jq -r --arg n "$need" '.verdict.jobs[] | select(.name == $n) | .result' <<<"$artifact")"
    [ "$observed" = "$recorded" ] ||
      die "gating need ${need} result ${recorded} disagrees with job conclusion ${observed}"
  done

  local summary_conclusion verdict
  summary_conclusion="$(jq -r '[.jobs[] | select(.name == "Nightly Summary") | .conclusion] | if length == 1 then .[0] else "missing" end' <<<"$run_json")"
  verdict="$(jq -r '.verdict.verdict' <<<"$artifact")"
  case "${verdict}:${summary_conclusion}" in
    green:success|red:failure) ;;
    *) die "strict verdict ${verdict} disagrees with Nightly Summary conclusion ${summary_conclusion}" ;;
  esac

  mkdir -p -- "$(dirname -- "$receipt")"
  receipt_dir="$(cd -- "$(dirname -- "$receipt")" && pwd)"
  receipt="${receipt_dir}/$(basename -- "$receipt")"
  temp_receipt="$(mktemp "${receipt_dir}/.nightly-scheduled-receipt.XXXXXX")"
  jq -nS --arg repository "$repo" --arg workflow "$workflow" \
    --argjson run "$run_json" --argjson artifact "$artifact" --arg summary "$summary_conclusion" '
      {schema:"rindle-nightly-scheduled-receipt-v1",repository:$repository,workflow:$workflow,
       event:$run.event,head_branch:$run.headBranch,head_sha:$run.headSha,run_id:$run.databaseId,
       run_attempt:$run.attempt,status:$run.status,conclusion:$run.conclusion,created_at:$run.createdAt,
       url:$run.url,jobs:($run.jobs | map({name,conclusion}) | sort_by(.name, .conclusion)),
       summary_conclusion:$summary,verdict:$artifact.verdict.verdict,
       gating_needs:($artifact.verdict.jobs | map({key:.name,value:.result}) | from_entries),
       verdict_artifact:$artifact}
    ' >"$temp_receipt" || { rm -f -- "$temp_receipt"; die "receipt rendering failed"; }
  ln "$temp_receipt" "$receipt" 2>/dev/null || { rm -f -- "$temp_receipt"; die "receipt destination appeared during collection"; }
  rm -f -- "$temp_receipt"
  echo "Recorded scheduled Nightly evidence for ${expected_sha} (run ${run_id}, $(jq -r .conclusion <<<"$run_json")) in ${receipt}"
}

main_ci_evidence() {
  local pages checks matches
  pages="$(gh api --paginate --slurp "repos/${repo}/commits/${expected_sha}/check-runs?per_page=100")" ||
    die "exact-SHA CI check lookup failed"
  checks="$(jq -ce 'if type == "array" then [.[].check_runs[]?] else [.check_runs[]?] end' <<<"$pages")" ||
    die "CI check response is malformed"
  matches="$(jq -ce --arg sha "$expected_sha" '[.[] | select(.name == "CI Summary" and .head_sha == $sha)]' <<<"$checks")" ||
    die "CI check response is malformed"
  [ "$(jq 'length' <<<"$matches")" -eq 1 ] || die "expected exactly one CI Summary check for ${expected_sha}"
  jq -e '.[0] | .status == "completed" and .conclusion == "success" and
    (.id | type == "number" and . > 0 and floor == .) and
    (.html_url | type == "string" and startswith("https://")) and
    (.completed_at | type == "string" and fromdateiso8601 >= 0)' <<<"$matches" >/dev/null ||
    die "CI Summary check is not completed and successful"
  jq -cnS --arg repo "$repo" --arg sha "$expected_sha" --argjson check "$(jq '.[0]' <<<"$matches")" \
    '{schema:"rindle-main-ci-receipt-v1",repository:$repo,subject_sha:$sha,check_id:$check.id,
      check_name:$check.name,status:$check.status,conclusion:$check.conclusion,url:$check.html_url,
      completed_at:$check.completed_at}'
}

verify_or_record_main_ci() {
  local evidence parent temp
  evidence="$(main_ci_evidence)"
  if [ -e "$receipt" ] || [ -L "$receipt" ]; then
    jq -e --argjson expected "$evidence" '
      . == $expected
    ' "$receipt" >/dev/null || die "CI receipt differs from the exact live CI Summary check"
    echo "CI Summary receipt valid for ${expected_sha} (check $(jq -r .check_id "$receipt"))"
    return 0
  fi
  parent="$(dirname -- "$receipt")"
  mkdir -p -- "$parent"
  parent="$(cd -- "$parent" && pwd)"
  receipt="${parent}/$(basename -- "$receipt")"
  temp="$(mktemp "${parent}/.main-ci-receipt.XXXXXX")"
  printf '%s\n' "$evidence" >"$temp"
  chmod 600 "$temp"
  ln "$temp" "$receipt" 2>/dev/null || { rm -f -- "$temp"; die "CI receipt destination appeared during capture"; }
  rm -f -- "$temp"
  echo "Recorded exact-SHA CI Summary receipt for ${expected_sha} in ${receipt}"
}

plan278_source_identity() {
  local head tree dirty remote
  [ -d "$source_root/.git" ] || [ -f "$source_root/.git" ] || die "source root is not a Git checkout"
  head="$(git -C "$source_root" rev-parse --verify HEAD 2>/dev/null)" || die "source root HEAD is unreadable"
  [ "$head" = "$expected_sha" ] || die "source root does not match the expected SHA"
  dirty="$(git -C "$source_root" status --porcelain --untracked-files=all)" || die "source root status is unreadable"
  [ -z "$dirty" ] || die "source root must be clean"
  tree="$(git -C "$source_root" rev-parse HEAD^{tree})" || die "source root tree is unreadable"
  remote="$(gh api "repos/${repo}/git/ref/heads/main" | jq -er '.object.sha')" || die "main ref lookup failed"
  [ "$remote" = "$expected_sha" ] || die "main moved away from the scheduled evidence subject"
  [ "$(cd "$source_root" && pwd -P)" != "$(cd "$evidence_root" && pwd -P)" ] ||
    die "source root and evidence root must be separate checkouts"
  jq -cnS --arg sha "$head" --arg tree "$tree" '{sha:$sha,tree:$tree,status:"pass"}'
}

plan278_local_evidence() {
  local ledger="${evidence_root}/.planning/phases/133-evidence-charter-and-live-truth/133-278-CENSUS-LEDGER.json"
  local receipt_a="${evidence_root}/.planning/phases/133-evidence-charter-and-live-truth/133-278-CENSUS-A.json"
  local receipt_b="${evidence_root}/.planning/phases/133-evidence-charter-and-live-truth/133-278-CENSUS-B.json"
  local mix_cmd="$source_root/scripts/maintainer/validate_evidence_census.exs" a b live
  for path in "$ledger" "$receipt_a" "$receipt_b"; do
    [ -s "$path" ] || die "Plan 278 local evidence is missing: $path"
  done
  a="$(cd "$source_root" && MIX_ENV=test MIX_DEPS_PATH="$source_root/deps" MIX_BUILD_PATH="$source_root/_build" \
    mix run --no-start --no-deps-check --no-compile "$mix_cmd" --root "$source_root" --ledger "$ledger" --receipt "$receipt_a")" ||
    die "census A did not validate against the exact source root"
  b="$(cd "$source_root" && MIX_ENV=test MIX_DEPS_PATH="$source_root/deps" MIX_BUILD_PATH="$source_root/_build" \
    mix run --no-start --no-deps-check --no-compile "$mix_cmd" --root "$source_root" --ledger "$ledger" --receipt "$receipt_b")" ||
    die "census B did not validate against the exact source root"
  cmp -s "$receipt_a" "$receipt_b" || die "census A and B receipts are not byte-identical"
  live="$(cd "$source_root" && MIX_ENV=test MIX_DEPS_PATH="$source_root/deps" MIX_BUILD_PATH="$source_root/_build" \
    mix run --no-start --no-deps-check --no-compile -e \
    'Code.require_file("scripts/maintainer/validate_live_truth.exs"); Rindle.ValidateLiveTruth.run(["--root", ".", "--format", "json"])')" ||
    die "live-truth model did not validate against the exact source root"
  jq -e --arg sha "$expected_sha" '.subject_sha == $sha and .status == "pass"' "$receipt_a" >/dev/null ||
    die "census receipts are not bound to the exact source SHA"
  jq -cnS --arg a "$(sha256_file "$receipt_a")" --arg b "$(sha256_file "$receipt_b")" \
    --arg live "$(printf '%s' "$live" | sha256_stream)" \
    '{census_a_sha256:$a,census_b_sha256:$b,live_truth_sha256:$live,status:"pass"}'
}

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'; fi
}

scheduled_checkpoint() {
  local run_id="$1" dir="$2" artifact="$3" checkpoint="$4" issues issue_digest event_digest chain_digest index verdict_index checkpoint_index
  index="$(gh api "repos/${repo}/actions/runs/${run_id}/artifacts?per_page=100")" || die "scheduled artifact inventory lookup failed"
  jq -e --arg run "$run_id" --arg sha "$expected_sha" '
    type == "object" and (.artifacts | type == "array") and
    ([.artifacts[] | select(.name == ("nightly-incident-verdict-" + $run + "-1"))] | length) == 1 and
    ([.artifacts[] | select(.name == ("nightly-incident-replay-checkpoint-" + $run + "-1"))] | length) == 1 and
    all(.artifacts[] | select(.name == ("nightly-incident-verdict-" + $run + "-1") or
      .name == ("nightly-incident-replay-checkpoint-" + $run + "-1"));
      .expired == false and (.id | type == "number" and . > 0 and floor == .) and
      (.digest | type == "string" and test("^sha256:[0-9a-f]{64}$")) and
      .workflow_run.id == ($run|tonumber) and .workflow_run.head_sha == $sha)
  ' <<<"$index" >/dev/null || die "scheduled verdict/checkpoint artifact inventory is duplicate, expired, or misbound"
  verdict_index="$(jq -cS --arg name "nightly-incident-verdict-${run_id}-1" '.artifacts[] | select(.name == $name) | {id,name,digest}' <<<"$index")"
  checkpoint_index="$(jq -cS --arg name "nightly-incident-replay-checkpoint-${run_id}-1" '.artifacts[] | select(.name == $name) | {id,name,digest}' <<<"$index")"
  gh run download "$run_id" --repo "$repo" --name "nightly-incident-verdict-${run_id}-1" --dir "$dir/verdict" >/dev/null 2>&1 ||
    die "scheduled verdict artifact is missing"
  gh run download "$run_id" --repo "$repo" --name "nightly-incident-replay-checkpoint-${run_id}-1" --dir "$dir/checkpoint" >/dev/null 2>&1 ||
    die "scheduled replay checkpoint artifact is missing"
  [ -f "$dir/verdict/nightly-incident-verdict.json" ] || die "scheduled verdict artifact is malformed"
  [ -f "$dir/checkpoint/nightly-incident-checkpoint.json" ] || die "scheduled checkpoint artifact is malformed"
  artifact="$(jq -cS . "$dir/verdict/nightly-incident-verdict.json")" || die "scheduled verdict artifact is unreadable"
  checkpoint="$(jq -cS . "$dir/checkpoint/nightly-incident-checkpoint.json")" || die "scheduled checkpoint artifact is unreadable"
  jq -e --arg repo "$repo" --arg sha "$expected_sha" --argjson run "$run_id" \
    '(keys | sort) == ["event","ref","repository","run_attempt","run_id","schema","sha","url","verdict","workflow_name","workflow_ref"] and
     .schema == "rindle-nightly-incident-verdict-v1" and .repository == $repo and
     .workflow_name == "Nightly" and .workflow_ref == ($repo + "/.github/workflows/" + "nightly.yml@refs/heads/main") and
     .event == "schedule" and .run_id == $run and .run_attempt == 1 and .sha == $sha and
     .ref == "refs/heads/main" and .url == ("https://github.com/" + $repo + "/actions/runs/" + ($run|tostring)) and
     .verdict.verdict == "green" and .verdict.errors == [] and
     ([.verdict.jobs[].name] | sort) == ["compat-matrix","dialyzer","gcs-soak","package-consumer-gcs-live"] and
     all(.verdict.jobs[];
       (keys | sort) == ["applicability_rule","applicable","errors","execution","name","reason","result","status"] and
       .errors == [] and (.applicable | type == "boolean") and
       (.applicability_rule | IN("always","upstream-repository-and-required-secrets")) and
       (if .applicable then .result == "success" and .execution == "passed" and .status == "passed" and .reason == ""
        else .execution == "not-run" and .status == "not-run" and .reason != "" and (.result | IN("success","skipped")) end))' \
    <<<"$artifact" >/dev/null || die "scheduled verdict artifact identity or verdict is invalid"
  jq -e --arg repo "$repo" --argjson run "$run_id" '
    (keys | sort) == ["chain_digest","event_digest","issue_digest","issue_number","issue_state","last_run_attempt","last_run_id","previous_chain_digest","repository","schema","workflow_ref"] and
    .schema == "rindle-nightly-incident-checkpoint-v1" and .repository == $repo and
    .workflow_ref == ($repo + "/.github/workflows/nightly.yml@refs/heads/main") and
    .last_run_id == $run and .last_run_attempt == 1 and
    (.event_digest | test("^[0-9a-f]{64}$")) and (.issue_digest | test("^[0-9a-f]{64}$")) and
    (.chain_digest | test("^[0-9a-f]{64}$")) and
    (.previous_chain_digest | test("^[0-9a-f]{64}$")) and
    (.issue_number == null or (.issue_number | type == "number" and . > 0)) and
    (.issue_state == null or (.issue_state | IN("OPEN","CLOSED")))
  ' <<<"$checkpoint" >/dev/null || die "scheduled incident checkpoint identity is malformed"
  event_digest="$(printf '%s\n' "$artifact" | sha256_stream)"
  [ "$event_digest" = "$(jq -r .event_digest <<<"$checkpoint")" ] || die "checkpoint event digest does not authenticate the verdict artifact"
  chain_digest="$(jq -cS '{previous_chain_digest,last_run_id,last_run_attempt,event_digest,issue_digest,issue_number,issue_state}' <<<"$checkpoint" | sha256_stream)"
  [ "$chain_digest" = "$(jq -r .chain_digest <<<"$checkpoint")" ] || die "checkpoint chain digest is invalid"
  issues="$(gh issue list --repo "$repo" --state all --label nightly-failure --limit 100 --json number,title,state,body,comments)" ||
    die "incident state lookup failed"
  jq -e --argjson checkpoint "$checkpoint" '
    type == "array" and all(.[]; (.number | type == "number") and (.title == "Nightly CI failure") and
      (.state | IN("OPEN","CLOSED")) and (.body | type == "string") and (.comments | type == "array")) and
    ([.[] | select(.state == "OPEN")] | length <= 1) and
    (if $checkpoint.issue_number == null then length == 0 else
      any(.[]; .number == $checkpoint.issue_number and .state == $checkpoint.issue_state)
    end)
  ' <<<"$issues" >/dev/null || die "incident issue state contradicts the scheduled checkpoint"
  issue_digest="$(jq -cS . <<<"$issues" | sha256_stream)"
  [ "$issue_digest" = "$(jq -r .issue_digest <<<"$checkpoint")" ] || die "incident issue digest differs from the scheduled checkpoint"
  jq -cnS --argjson artifact "$artifact" --argjson checkpoint "$checkpoint" \
    --argjson verdict_artifact "$verdict_index" --argjson checkpoint_artifact "$checkpoint_index" \
    --arg artifact_sha256 "$(printf '%s\n' "$artifact" | sha256_stream)" \
    --arg checkpoint_sha256 "$(printf '%s\n' "$checkpoint" | sha256_stream)" \
    --arg issue_sha256 "$issue_digest" \
    '{verdict:$artifact,verdict_sha256:$artifact_sha256,verdict_artifact:$verdict_artifact,
      checkpoint:$checkpoint,checkpoint_artifact:$checkpoint_artifact,
      checkpoint_sha256:$checkpoint_sha256,incident_state_sha256:$issue_sha256,status:"pass"}'
}

capture_plan278_scheduled() {
  local previous_receipt="$receipt" tempdir source local_evidence legacy_receipt run_id run_json jobs logs dialyzer incident scheduled_json receipt_dir temp_receipt
  source="$(plan278_source_identity)" || die "source identity validation failed"
  local_evidence="$(plan278_local_evidence)" || die "local census and live-truth validation failed"
  tempdir="$(mktemp -d "${TMPDIR:-/tmp}/plan278-scheduled.XXXXXX")"
  legacy_receipt="$tempdir/legacy.json"
  receipt="$legacy_receipt"
  run_id_arg=""
  verify_scheduled >/dev/null || { receipt="$previous_receipt"; rm -rf -- "$tempdir"; return 1; }
  run_id="$(jq -er .run_id "$legacy_receipt")"
  run_json="$(gh run view "$run_id" --repo "$repo" --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" || {
    receipt="$previous_receipt"; rm -rf -- "$tempdir"; die "scheduled run detail lookup failed"
  }
  jobs="$(expected_job_names_json)"
  jq -e --argjson expected "$jobs" '
    .workflowName == "Nightly" and .event == "schedule" and .headBranch == "main" and
    .attempt == 1 and .status == "completed" and .conclusion == "success" and
    ([.jobs[].name] | sort) == ($expected | sort) and
    all(.jobs[]; .status == "completed" and
      (if .name == "GCS Soak (real bucket)" then .conclusion == "success" or .conclusion == "skipped" else .conclusion == "success" end))
  ' <<<"$run_json" >/dev/null || { receipt="$previous_receipt"; rm -rf -- "$tempdir"; die "scheduled Nightly does not have the exact successful job set"; }
  logs="$(job_logs "$run_id" "$run_json" "Dialyzer")"
  logs+=$'\n'
  logs+="$(job_logs "$run_id" "$run_json" "Nightly Summary")"
  dialyzer="$(parse_log_evidence "$logs")"
  incident="$(scheduled_checkpoint "$run_id" "$tempdir" "" "")"
  scheduled_json="$(jq -nS --arg repo "$repo" --arg workflow "$workflow" --argjson run "$run_json" \
    --argjson dialyzer "$dialyzer" --argjson incident "$incident" --argjson source "$source" --argjson local "$local_evidence" '
      {schema:"rindle-plan278-scheduled-receipt-v1",repository:$repo,workflow:$workflow,event:$run.event,
       head_branch:$run.headBranch,head_sha:$run.headSha,run_id:$run.databaseId,run_attempt:$run.attempt,
       status:$run.status,conclusion:$run.conclusion,created_at:$run.createdAt,url:$run.url,
       jobs:($run.jobs | sort_by(.name) | map({id:.databaseId,name,status,conclusion})),
       dialyzer:$dialyzer,strict_verdict:{summary_job:"Nightly Summary",verdict:"green"},
       incident:$incident,source:$source,local_evidence:$local}
    ' 2>"$tempdir/render.err")" || {
      local render_error="$(cat "$tempdir/render.err" 2>/dev/null || true)"
      receipt="$previous_receipt"; rm -rf -- "$tempdir"
      die "scheduled receipt rendering failed: ${render_error}"
    }
  receipt="$previous_receipt"
  rm -rf -- "$tempdir"
  printf '%s\n' "$scheduled_json"
}

run_plan278_schedule_mode() {
  local expected receipt_abs generated evidence_abs receipt_parent
  expected="$(plan278_source_identity)" || die "source identity validation failed"
  [ "$(jq -r .sha <<<"$expected")" = "$expected_sha" ] || die "source SHA differs from the receipt subject"
  evidence_abs="$(cd "$evidence_root" && pwd -P)" || die "evidence root is unreadable"
  if [[ "$receipt" != /* ]]; then receipt="${evidence_root}/${receipt}"; fi
  receipt_parent="$(cd "$(dirname -- "$receipt")" 2>/dev/null && pwd -P)" || die "receipt parent is outside the evidence checkout"
  [[ "$receipt_parent" == "$evidence_abs" || "$receipt_parent" == "$evidence_abs/"* ]] ||
    die "scheduled receipt path must remain inside the evidence checkout"
  if [ "$mode" = capture-scheduled-and-record ]; then
    [ ! -e "$receipt" ] && [ ! -L "$receipt" ] || die "receipt destination already exists"
    generated="$(capture_plan278_scheduled)" || die "scheduled Nightly evidence capture failed"
    mkdir -p -- "$(dirname -- "$receipt")"
    receipt_abs="$(cd -- "$(dirname -- "$receipt")" && pwd)/$(basename -- "$receipt")"
    printf '%s\n' "$generated" >"${receipt_abs}.tmp.$$"
    chmod 600 "${receipt_abs}.tmp.$$"
    ln "${receipt_abs}.tmp.$$" "$receipt_abs" || { rm -f "${receipt_abs}.tmp.$$"; die "receipt destination appeared during capture"; }
    rm -f "${receipt_abs}.tmp.$$"
    echo "Recorded Plan 278 scheduled evidence for ${expected_sha} in ${receipt_abs}"
  else
    [ -s "$receipt" ] || die "scheduled receipt is missing"
    generated="$(capture_plan278_scheduled)" || die "scheduled Nightly evidence verification failed"
    jq -e --argjson expected "$generated" '. == $expected' "$receipt" >/dev/null ||
      die "scheduled receipt differs from the exact live run and incident evidence"
    echo "Plan 278 scheduled receipt valid for ${expected_sha} (run $(jq -r .run_id "$receipt"), attempt 1)"
  fi
}

if [ "$mode" = capture-scheduled-and-record ] || [ "$mode" = verify-scheduled-receipt ]; then
  run_plan278_schedule_mode
  exit 0
fi

if [ "$mode" = verify-main-ci-receipt ]; then
  verify_or_record_main_ci
  exit 0
fi

if [ "$mode" = verify-scheduled ]; then
  verify_scheduled
  exit 0
fi

if [ "$mode" = preflight ]; then
  preflight_json
  exit 0
fi

if [ "$mode" = verify-receipt ]; then
  live_preflight="$(preflight_json)"
  verify_receipt_shape "$receipt"
  run_id="$(jq -er '.run_id' "$receipt")"
  live_run="$(gh run view "$run_id" --repo "$repo" --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" || die "run verification lookup failed"
  validate_run_json "$live_run"
  [ "$(jq -r '.run_id' "$receipt")" = "$(jq -r '.databaseId' <<<"$live_run")" ] || die "receipt run ID differs from GitHub"
  live_dialyzer_logs="$(job_logs "$run_id" "$live_run" "Dialyzer")"
  live_summary_logs="$(job_logs "$run_id" "$live_run" "Nightly Summary")"
  live_dialyzer="$(parse_log_evidence "${live_dialyzer_logs}"$'\n'"${live_summary_logs}")"
  expected_remote="$(expected_remote_from_live "$live_preflight" "$live_run" "$live_dialyzer")"
  compare_exact_remote_receipt "$receipt" "$expected_remote"
  live_incidents="$(canonical_incidents)" || die "incident verification lookup failed"
  recorded_census="$(jq -c '.local_authorities.census' "$receipt")"
  live_local_authorities="$(revalidate_local_authorities "$recorded_census")"
  compare_exact_local_and_incident_receipt "$receipt" "$live_incidents" "$live_local_authorities"
  echo "Nightly receipt valid for ${expected_sha} (run ${run_id}, attempt 1)"
  exit 0
fi

cleanup_path=""
cleanup() {
  if [ -n "$cleanup_path" ]; then rm -f -- "$cleanup_path"; fi
}
trap cleanup EXIT
if [ -e "$receipt" ] || [ -L "$receipt" ]; then
  die "receipt destination already exists"
fi
mkdir -p -- "$(dirname -- "$receipt")"
receipt_dir="$(cd -- "$(dirname -- "$receipt")" && pwd)"
receipt="${receipt_dir}/$(basename -- "$receipt")"
temp_receipt="$(mktemp "${receipt_dir}/.nightly-receipt.XXXXXX")"
chmod 600 "$temp_receipt"
cleanup_path="$temp_receipt"
preflight="$(preflight_json)"
incident_before="$(canonical_incidents)" || die "incident snapshot before dispatch failed"
pre_dispatch_ids="$(matching_run_ids)"

gh workflow run "$workflow" --repo "$repo" --ref "$remote_ref" || die "workflow dispatch failed"
deadline=$(( $(date +%s) + timeout_seconds ))
run_id=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  post_dispatch_ids="$(matching_run_ids true)"
  new_matching_ids="$(jq -cn --argjson before "$pre_dispatch_ids" --argjson after "$post_dispatch_ids" \
    '$after - $before')" || die "could not subtract the pre-dispatch run snapshot"
  match_count="$(jq 'length' <<<"$new_matching_ids")"
  case "$match_count" in
    0) ;;
    1)
      run_id="$(jq -r '.[0]' <<<"$new_matching_ids")"
      break
      ;;
    *) die "ambiguous new exact diagnostic run selection: found ${match_count} IDs absent before dispatch" ;;
  esac
  [ "$poll_seconds" -eq 0 ] || sleep "$poll_seconds"
done
[ -n "$run_id" ] || die "timed out waiting for exact diagnostic run"

read_with_rate_limit_recovery gh run watch "$run_id" --repo "$repo" --interval "$poll_seconds" >/dev/null ||
  die "GitHub run watch failed after bounded observation"
run_json="$(read_with_rate_limit_recovery gh run view "$run_id" --repo "$repo" \
  --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,status,url,workflowName)" ||
  die "run detail lookup failed after bounded observation"
validate_run_json "$run_json"
[ "$run_id" = "$(jq -r '.databaseId' <<<"$run_json")" ] ||
  die "selected run ID differs from the detailed run identity"
dialyzer_logs="$(job_logs "$run_id" "$run_json" "Dialyzer" true)"
summary_logs="$(job_logs "$run_id" "$run_json" "Nightly Summary" true)"
dialyzer="$(parse_log_evidence "${dialyzer_logs}"$'\n'"${summary_logs}")"
local_authorities="$(revalidate_local_authorities)"
incident_after="$(canonical_incidents true)" || die "incident snapshot after dispatch failed"
[ "$incident_before" = "$incident_after" ] || die "workflow_dispatch changed the nightly-failure incident"

jq -nS \
  --arg repository "$repo" --arg workflow "$workflow" --arg event workflow_dispatch \
  --arg subject_sha "$expected_sha" --arg remote_ref "$remote_ref" \
  --argjson run "$run_json" --argjson dialyzer "$dialyzer" \
  --argjson before "$incident_before" --argjson after "$incident_after" \
  --argjson local_authorities "$local_authorities" --argjson preflight "$preflight" '
    {schema_version:2,repository:$repository,workflow:$workflow,event:$event,
     subject_sha:$subject_sha,remote_ref:$remote_ref,run_id:$run.databaseId,
     run_attempt:$run.attempt,conclusion:$run.conclusion,created_at:$run.createdAt,
     jobs:($run.jobs | sort_by(.name) | map({id:.databaseId,name,status,conclusion})),
     dialyzer:$dialyzer,strict_verdict:{verdict:"green",summary_job:"Nightly Summary"},
     incident_snapshot_before:$before,incident_snapshot_after:$after,
     local_authorities:$local_authorities,preflight:$preflight}
  ' >"$temp_receipt"
verify_receipt_shape "$temp_receipt"
ln "$temp_receipt" "$receipt" || die "receipt destination appeared during collection"
rm -f -- "$temp_receipt"
cleanup_path=""
echo "Recorded exact Nightly evidence for ${expected_sha} in ${receipt}"
