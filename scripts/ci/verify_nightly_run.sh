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
      (all($jobs[]; .status == "completed" and .conclusion == "success" and
        (.databaseId | type == "number")))
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
  local run_id="$1" run_json="$2" job_name="$3" job_id
  job_id="$(jq -er --arg name "$job_name" '.jobs[] | select(.name == $name) | .databaseId' <<<"$run_json")" ||
    die "missing job ID for ${job_name}"
  gh run view "$run_id" --repo "$repo" --job "$job_id" --log ||
    die "${job_name} log lookup failed"
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
    (.jobs | type == "array" and length == 10 and
      [.[].name] == $expected_jobs and ([.[].id] | unique | length) == 10 and
      all(.[]; exact_keys(["conclusion","id","name","status"]) and (.id | type == "number") and
        (.name | type == "string") and .status == "completed" and .conclusion == "success")) and
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
      "$mix_executable" run --no-deps-check --no-compile scripts/maintainer/evidence_census.exs \
        --root . \
        --ledger "$ledger_file" \
        --output "$census_receipt" \
        --source-sha "$expected_sha" >/dev/null
    PATH="$authority_path" MIX_ENV=test MIX_DEPS_PATH="${project_root}/deps" MIX_BUILD_PATH="${project_root}/_build" \
      "$mix_executable" run --no-deps-check --no-compile scripts/maintainer/validate_evidence_census.exs \
        --root . \
        --ledger "$ledger_file" \
        --receipt "$census_receipt" >/dev/null
    PATH="$authority_path" MIX_ENV=test MIX_DEPS_PATH="${project_root}/deps" MIX_BUILD_PATH="${project_root}/_build" \
      "$mix_executable" run --no-deps-check --no-compile -e \
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
    .incident_snapshot_before == $incidents and
    .incident_snapshot_after == $incidents
  ' "$path" >/dev/null || die "receipt incident evidence is stale relative to the fresh exact-label snapshot"
  jq -e --argjson local "$local_authorities" '.local_authorities == $local' "$path" >/dev/null ||
    die "receipt local-authority evidence differs from exact-subject revalidation"
}

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
  case "$match_count" in
    0) ;;
    1)
      run_id="$(jq -r '.[0].databaseId' <<<"$matches")"
      break
      ;;
    *) die "ambiguous exact diagnostic run selection: found ${match_count} post-boundary matches" ;;
  esac
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
local_authorities="$(revalidate_local_authorities)"
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
    {schema_version:2,repository:$repository,workflow:$workflow,event:$event,
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
