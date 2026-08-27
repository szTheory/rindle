#!/usr/bin/env bash
# Unattended, fail-closed pull-request timing sampler and receipt verifier.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage:
  collect_pr_timing_receipt.sh preflight|run [options]
  collect_pr_timing_receipt.sh verify --repo OWNER/REPO --pr N --workflow FILE --summary-job NAME
    --samples N --median-max SECONDS --p95-max SECONDS --receipt PATH

run/preflight options:
  --repo OWNER/REPO --pr N --workflow FILE --summary-job NAME --label NAME
  --samples N --max-sequences N --median-max SECONDS --p95-max SECONDS
  --correction-sha SHA --preserved-subject-sha SHA --transition-manifest PATH --receipt PATH
  [--state-dir PATH] [--publish-head|--no-publish] [--poll-seconds N]
EOF
}

die() {
  echo "[ci-timing] ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

mode="${1:-}"
[ -n "$mode" ] || { usage; exit 64; }
shift

repo=""
pr=""
workflow="ci.yml"
summary_job="CI Summary"
label="ci-timing-sample"
samples=10
max_sequences=2
median_max=480
p95_max=600
correction_sha=""
preserved_subject_sha=""
transition_manifest=""
receipt=""
state_dir=".gsd/ci-timing"
publish_head=1
poll_seconds=15
creation_timeout=300
run_timeout=1800

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --pr) pr="$2"; shift 2 ;;
    --workflow) workflow="$2"; shift 2 ;;
    --summary-job) summary_job="$2"; shift 2 ;;
    --label) label="$2"; shift 2 ;;
    --samples) samples="$2"; shift 2 ;;
    --max-sequences) max_sequences="$2"; shift 2 ;;
    --median-max) median_max="$2"; shift 2 ;;
    --p95-max) p95_max="$2"; shift 2 ;;
    --correction-sha) correction_sha="$2"; shift 2 ;;
    --preserved-subject-sha) preserved_subject_sha="$2"; shift 2 ;;
    --transition-manifest) transition_manifest="$2"; shift 2 ;;
    --receipt) receipt="$2"; shift 2 ;;
    --state-dir) state_dir="$2"; shift 2 ;;
    --publish-head) publish_head=1; shift ;;
    --no-publish) publish_head=0; shift ;;
    --poll-seconds) poll_seconds="$2"; shift 2 ;;
    --creation-timeout) creation_timeout="$2"; shift 2 ;;
    --run-timeout) run_timeout="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command jq

validate_transition_manifest() {
  local path="$1" json markers declared actual duplicate stage from_sha to_sha expected_paths actual_paths entry_path blob_oid actual_blob
  [ -s "$path" ] || die "transition manifest is missing or empty: $path"
  markers="$(grep -c '^PRESERVATION_TRANSITION_V2_BEGIN$' "$path" || true)"
  [ "$markers" -eq 1 ] || die "transition manifest must contain exactly one PRESERVATION_TRANSITION_V2_BEGIN marker"
  markers="$(grep -c '^PRESERVATION_TRANSITION_V2_END$' "$path" || true)"
  [ "$markers" -eq 1 ] || die "transition manifest must contain exactly one PRESERVATION_TRANSITION_V2_END marker"
  json="$(awk '$0 == "PRESERVATION_TRANSITION_V2_BEGIN" {take=1; next} $0 == "PRESERVATION_TRANSITION_V2_END" {take=0} take' "$path")"

  jq -e --arg repo "$repo" --argjson pr "$pr" --arg correction "$correction_sha" --arg repair "$preserved_subject_sha" --arg subject "$preserved_subject_sha" '
    .schema_version == 2 and .repo == $repo and .pr == $pr and
    (.prior_preserved_sha | type == "string" and test("^[0-9a-f]{40}$")) and
    .controller_correction_sha == $correction and
    (.formatter_correction_sha | type == "string" and test("^[0-9a-f]{40}$")) and
    .repair_sha == $repair and .preserved_subject_sha == $subject and .repair_sha == .preserved_subject_sha and
    (.stages | type == "array" and length == 3) and
    ([.stages[].id] == ["plan-132-12", "plan-132-13", "plan-132-14-repair"]) and
    (.stages[0].from_sha == .prior_preserved_sha and .stages[0].to_sha == .controller_correction_sha) and
    (.stages[1].from_sha == .stages[0].to_sha and .stages[1].to_sha == .formatter_correction_sha) and
    (.stages[2].from_sha == .stages[1].to_sha and .stages[2].to_sha == .repair_sha) and
    all(.stages[]; (.from_sha | type == "string" and test("^[0-9a-f]{40}$")) and (.to_sha | type == "string" and test("^[0-9a-f]{40}$")) and (.planning | type == "array") and (.non_planning | type == "array")) and
    all(.stages[]; all((.planning + .non_planning)[]; (.status == "A" or .status == "M") and (.path | type == "string" and length > 0))) and
    all(.stages[]; all(.planning[]; .path | startswith(".planning/"))) and
    all(.stages[]; all(.non_planning[]; (.path | startswith(".planning/") | not) and (.blob_oid | type == "string" and test("^[0-9a-f]{40}$"))))
  ' <<<"$json" >/dev/null || die "transition manifest schema, identity, or chronology is invalid"

  # The anchors must be real, adjacent first-parent-independent Git history.  No
  # manifest assertion is trusted until the repository reproduces it exactly.
  while IFS=$'\t' read -r stage from_sha to_sha; do
    git rev-parse --verify "${from_sha}^{commit}" >/dev/null 2>&1 || die "transition manifest has an unknown from SHA"
    git rev-parse --verify "${to_sha}^{commit}" >/dev/null 2>&1 || die "transition manifest has an unknown to SHA"
    git merge-base --is-ancestor "$from_sha" "$to_sha" || die "transition manifest stage $stage is reversed"
    [ "$from_sha" != "$to_sha" ] || die "transition manifest stage $stage is empty"

    declared="$(jq -r --arg id "$stage" '.stages[] | select(.id == $id) | (.planning[]?, .non_planning[]?) | "\(.status)\t\(.path)"' <<<"$json" | LC_ALL=C sort)"
    actual="$(git diff-tree --no-commit-id -r --no-renames --name-status "$from_sha" "$to_sha" | awk 'NF == 2 {print $1 "\t" $2}' | LC_ALL=C sort)"
    [ "$declared" = "$actual" ] || die "transition manifest stage $stage does not exactly match its Git delta"
    duplicate="$(printf '%s\n' "$declared" | sed '/^$/d' | uniq -d)"
    [ -z "$duplicate" ] || die "transition manifest stage $stage declares a path more than once"

    while IFS=$'\t' read -r entry_path blob_oid; do
      [ -n "$entry_path" ] || continue
      actual_blob="$(git rev-parse "${to_sha}:${entry_path}" 2>/dev/null || true)"
      [ "$actual_blob" = "$blob_oid" ] || die "transition manifest blob does not match $entry_path"
    done < <(jq -r --arg id "$stage" '.stages[] | select(.id == $id) | .non_planning[] | "\(.path)\t\(.blob_oid)"' <<<"$json")
  done < <(jq -r '.stages[] | [.id, .from_sha, .to_sha] | @tsv' <<<"$json")

  # These are the only executable handoffs in the repaired chronology.  In
  # particular, formatter evidence has its own stage and cannot be recast as
  # planning-only provenance.
  jq -e '
    (.stages[0].non_planning | map(.path) | sort) == ["scripts/ci/collect_pr_timing_receipt.sh", "test/install_smoke/ci_timing_automation_test.exs"] and
    (.stages[1].non_planning | map(.path) | sort) == ["test/install_smoke/ci_lane_split_test.exs"] and
    (.stages[2].non_planning | map(.path) | sort) == ["scripts/ci/collect_pr_timing_receipt.sh", "test/install_smoke/ci_timing_automation_test.exs"]
  ' <<<"$json" >/dev/null || die "transition manifest has an unauthorized executable stage assignment"

  # Everything after the immutable preserved subject is planning evidence only;
  # do not retain an allowlist that could hide a later executable mutation.
  actual_paths="$(git diff --name-only "$preserved_subject_sha..$head_sha" | grep -Ev '^\.planning/' || true)"
  [ -z "$actual_paths" ] || die "non-planning files changed after preservation: ${actual_paths//$'\n'/, }"
}

current_manifest_from_receipt() {
  local path="$1"
  awk '$0 == "CI_TIMING_CURRENT_SOURCE_BEGIN" {take=1; next} $0 == "CI_TIMING_CURRENT_SOURCE_END" {take=0} take' "$path"
}

verify_current_receipt_shape() {
  local path="$1" manifest table_rows manifest_rows
  [ -s "$path" ] || die "receipt is missing or empty: $path"
  [ "$(grep -c '^CI_TIMING_CURRENT_SOURCE_BEGIN$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_CURRENT_SOURCE_BEGIN marker"
  [ "$(grep -c '^CI_TIMING_CURRENT_SOURCE_END$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_CURRENT_SOURCE_END marker"
  [ "$(grep -c '^CI_TIMING_CURRENT_TABLE_BEGIN$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_CURRENT_TABLE_BEGIN marker"
  [ "$(grep -c '^CI_TIMING_CURRENT_TABLE_END$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_CURRENT_TABLE_END marker"

  manifest="$(current_manifest_from_receipt "$path")"
  jq -e --argjson expected "$samples" '
    (.sha | test("^[0-9a-f]{40}$")) and
    (.repo | type == "string" and length > 0) and
    (.pr | type == "number" and . > 0) and
    (.runs | type == "array" and length == $expected) and
    (.population_boundary_ids | type == "array") and
    (([.runs[].id] | unique | length) == $expected) and
    (all(.runs[]; (.id | type) == "number" and (.duration_seconds | type) == "number" and .duration_seconds >= 0)) and
    ((.median_seconds | type) == "number") and
    ((.p95_seconds | type) == "number")
  ' <<<"$manifest" >/dev/null || die "receipt manifest must contain exactly $samples runs with valid timing data"

  table_rows="$(awk '
    $0 == "CI_TIMING_CURRENT_TABLE_BEGIN" {take=1; next}
    $0 == "CI_TIMING_CURRENT_TABLE_END" {take=0}
    take && $0 ~ /^\| [0-9]+ \| [0-9]+ \|/ {
      gsub(/^\| /, ""); split($0, c, " \\| "); print c[2] "\t" c[5]
    }
  ' "$path" | jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {id:(.[0]|tonumber), duration_seconds:(.[1]|tonumber)})')"
  manifest_rows="$(jq -c '.runs | map({id, duration_seconds})' <<<"$manifest")"
  [ "$(jq -c . <<<"$table_rows")" = "$manifest_rows" ] || die "receipt table rows do not match the machine-readable manifest"

  local recalculated
  recalculated="$(jq -c '
    [.runs[].duration_seconds] | sort as $v |
    {median:(($v[4] + $v[5]) / 2), p95:$v[9]}
  ' <<<"$manifest")"
  [ "$(jq -r '.median' <<<"$recalculated")" = "$(jq -r '.median_seconds' <<<"$manifest")" ] || die "receipt median does not match its durations"
  [ "$(jq -r '.p95' <<<"$recalculated")" = "$(jq -r '.p95_seconds' <<<"$manifest")" ] || die "receipt p95 does not match its durations"
}

verify_api_backed_receipt() {
  local path="$1" expected_sha="${2:-}" manifest run id run_api jobs_api actual selected eligible chronology previous_end current_start statistics
  verify_current_receipt_shape "$path"
  manifest="$(current_manifest_from_receipt "$path")"
  [ "$(jq -r '.sha | length == 40' <<<"$manifest")" = true ] || die "current receipt SHA must be immutable"
  [ -z "$expected_sha" ] || [ "$(jq -r .sha <<<"$manifest")" = "$expected_sha" ] || die "current receipt SHA does not match the controller head"
  [ "$(jq -r .repo <<<"$manifest")" = "$repo" ] || die "current receipt repository does not match --repo"
  [ "$(jq -r .pr <<<"$manifest")" = "$pr" ] || die "current receipt PR does not match --pr"

  while IFS= read -r run; do
    id="$(jq -r '.id' <<<"$run")"
    run_api="$(gh api -H 'Accept: application/vnd.github+json' "repos/${repo}/actions/runs/${id}")" || die "unable to resolve Actions run $id"
    jobs_api="$(gh api -H 'Accept: application/vnd.github+json' "repos/${repo}/actions/runs/${id}/jobs?per_page=100")" || die "unable to resolve Actions jobs for $id"
    actual="$(jq -cn --argjson expected "$run" --argjson api "$run_api" --argjson jobs "$jobs_api" --arg name "$summary_job" '
      ($jobs | (if type == "array" then [.[].jobs[]] else [.jobs[]] end) | [.[] | select(.name == $name)]) as $summary |
      if ($summary|length) != 1 then error("CI Summary must appear exactly once")
      elif ($api.event != "pull_request" or $api.head_sha != $expected.sha or $api.run_attempt != 1 or $api.status != "completed" or $api.conclusion != "success") then error("run identity is not qualifying")
      elif ($summary[0].status != "completed" or $summary[0].conclusion != "success" or $api.run_started_at == null or $summary[0].completed_at == null) then error("summary is not qualifying")
      else {id:$api.id, sha:$api.head_sha, url:($api.html_url // ""), started_at:$api.run_started_at, summary_completed_at:$summary[0].completed_at, duration_seconds:(($summary[0].completed_at|fromdateiso8601)-($api.run_started_at|fromdateiso8601))} end
    ' 2>/dev/null)" || die "run $id failed Actions identity or CI Summary validation"
    jq -e --argjson expected "$run" --argjson actual "$actual" '
      $actual.duration_seconds >= 0 and
      $expected.id == $actual.id and $expected.sha == $actual.sha and
      $expected.started_at == $actual.started_at and
      $expected.duration_seconds == $actual.duration_seconds and
      (($expected.url // $actual.url) == $actual.url)
    ' >/dev/null || die "run $id differs from the current receipt manifest"
  done < <(jq -c '.sha as $sha | .runs[] | . + {sha:$sha}' <<<"$manifest")

  selected="$(jq -c '[.runs[].id]' <<<"$manifest")"
  eligible="$(canonical_eligible_run_ids "$(jq -r .sha <<<"$manifest")" "$(jq -c .population_boundary_ids <<<"$manifest")")"
  [ "$eligible" = "$selected" ] || die "selected run IDs do not equal the complete canonical eligible population"
  previous_end=0
  chronology="$(jq -r '.runs[] | . as $run | [($run.started_at | fromdateiso8601), ($run.summary_completed_at | fromdateiso8601)] | @tsv' <<<"$manifest")" || die "current receipt chronology is malformed"
  while IFS=$'\t' read -r current_start current_end; do
    [ "$current_start" -ge "$previous_end" ] || die "current receipt samples overlap"
    previous_end="$current_end"
  done <<<"$chronology"

  statistics="$(jq -c '
    [.runs[].duration_seconds] | sort as $v |
    {median:(($v[4] + $v[5]) / 2), p95:$v[9]}
  ' <<<"$manifest")"
  jq -e --argjson stats "$statistics" '
    .median_seconds == $stats.median and .p95_seconds == $stats.p95
  ' <<<"$manifest" >/dev/null || die "current receipt statistics disagree with its live population"
  jq -e --argjson median_max "$median_max" --argjson p95_max "$p95_max" --argjson stats "$statistics" '
    $stats.median <= $median_max and $stats.p95 <= $p95_max
  ' <<<"$manifest" >/dev/null || return 2
}

# The only authority for selecting evidence. Every caller is bound to the same
# repository, numeric PR, immutable SHA, workflow, and deterministic ordering.
canonical_eligible_run_ids() {
  local sha="$1" boundary_ids="${2:-[]}" pr_identity workflow_runs
  pr_identity="$(gh pr view "$pr" --repo "$repo" --json headRefOid)" || die "unable to resolve PR identity"
  [ "$(jq -r .headRefOid <<<"$pr_identity")" = "$sha" ] || die "PR head does not match immutable timing SHA"
  workflow_runs="$(gh api -H 'Accept: application/vnd.github+json' "repos/${repo}/actions/workflows/${workflow}/runs?event=pull_request&per_page=100")" || die "unable to resolve canonical Actions population"
  jq -c --arg sha "$sha" --argjson pr "$pr" --argjson boundary "$boundary_ids" '
    [(if type == "array" then .[].workflow_runs[] else .workflow_runs[] end) |
      select(.event == "pull_request" and .head_sha == $sha and .run_attempt == 1 and
        .status == "completed" and .conclusion == "success" and
        any(.pull_requests[]?; .number == $pr) and
        ((.id as $id | $boundary | index($id)) == null))] |
    sort_by(.run_started_at, .id) | map(.id)
  ' <<<"$workflow_runs" || die "unable to derive canonical eligible run IDs"
}

if [ "$mode" = verify ]; then
  require_command gh
  [ "$repo" = "szTheory/rindle" ] || die "verify requires --repo szTheory/rindle"
  [[ "$pr" =~ ^[1-9][0-9]*$ ]] || die "verify requires --pr"
  [ "$workflow" = "ci.yml" ] || die "verify requires --workflow ci.yml"
  [ "$summary_job" = "CI Summary" ] || die "verify requires --summary-job CI Summary"
  [ -n "$receipt" ] || die "--receipt is required"
  [ "$samples" -eq 10 ] || die "--samples must be exactly 10 for the CI-14 contract"
  verify_api_backed_receipt "$receipt" || {
    status=$?
    [ "$status" -eq 2 ] && die "current receipt misses inclusive CI-14 timing thresholds"
    exit "$status"
  }
  echo "[ci-timing] receipt verification passed: $receipt"
  exit 0
fi

case "$mode" in preflight|run) ;; *) usage; exit 64 ;; esac

require_command gh
require_command git
[ -n "$repo" ] || die "--repo is required"
[ -n "$pr" ] || die "--pr is required"
[[ "$pr" =~ ^[1-9][0-9]*$ ]] || die "--pr must be a positive integer"
[ -n "$correction_sha" ] || die "--correction-sha is required"
[ -n "$preserved_subject_sha" ] || die "--preserved-subject-sha is required"
[ -n "$transition_manifest" ] || die "--transition-manifest is required"
[ -n "$receipt" ] || die "--receipt is required"
[[ "$samples" =~ ^[0-9]+$ ]] && [ "$samples" -eq 10 ] || die "--samples must be exactly 10 for the CI-14 contract"
[[ "$max_sequences" =~ ^[0-9]+$ ]] && [ "$max_sequences" -ge 1 ] || die "--max-sequences must be a positive integer"
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || die "--poll-seconds must be a non-negative integer"

gh auth status >/dev/null 2>&1 || die "gh authentication is required"
head_sha="$(git rev-parse HEAD)"
correction_sha="$(git rev-parse "$correction_sha")"
preserved_subject_sha="$(git rev-parse "$preserved_subject_sha")"
[ "${#head_sha}" -eq 40 ] || die "HEAD did not resolve to a full SHA"
git merge-base --is-ancestor "$correction_sha" "$head_sha" || die "correction SHA is not an ancestor of HEAD"
git merge-base --is-ancestor "$preserved_subject_sha" "$head_sha" || die "preserved subject SHA is not an ancestor of HEAD"

pr_json="$(gh pr view "$pr" --repo "$repo" --json state,isDraft,headRefName,headRefOid,labels)"
[ "$(jq -r '.state' <<<"$pr_json")" = OPEN ] || die "PR #$pr is not open"
head_ref="$(jq -r '.headRefName' <<<"$pr_json")"
remote_sha="$(jq -r '.headRefOid' <<<"$pr_json")"
[ -n "$head_ref" ] && [ "$head_ref" != null ] || die "PR head branch is unavailable"
encoded_head_ref="$(jq -rn --arg value "$head_ref" '$value | @uri')"

gh label list --repo "$repo" --limit 100 --json name --jq '.[].name' | grep -Fxq "$label" || die "label does not exist: $label"
if jq -e --arg label_name "$label" 'any(.labels[]?; .name == $label_name)' <<<"$pr_json" >/dev/null; then
  die "PR already has $label; refusing to take ownership of a pre-existing trigger label"
fi

validate_transition_manifest "$transition_manifest"

published_now=0
if [ "$publish_head" -eq 1 ] && [ "$remote_sha" != "$head_sha" ]; then
  git fetch --quiet origin "$head_ref"
  git merge-base --is-ancestor "$remote_sha" "$head_sha" || die "remote PR head is not an ancestor of local HEAD; refusing non-fast-forward publication"
  echo "[ci-timing] fast-forward publishing $head_sha to $head_ref"
  git push --porcelain origin "HEAD:refs/heads/$head_ref"
  deadline=$(( $(date +%s) + 60 ))
  while :; do
    remote_sha="$(gh pr view "$pr" --repo "$repo" --json headRefOid --jq .headRefOid)"
    [ "$remote_sha" = "$head_sha" ] && break
    [ "$(date +%s)" -lt "$deadline" ] || die "PR head did not converge to published SHA"
    sleep 2
  done
  published_now=1
elif [ "$remote_sha" != "$head_sha" ]; then
  git merge-base --is-ancestor "$remote_sha" "$head_sha" || die "remote PR head is not an ancestor of local HEAD; refusing non-fast-forward publication"
  echo "[ci-timing] publication-ready: remote PR head $remote_sha is a strict ancestor of local HEAD"
fi

echo "[ci-timing] preflight passed: $repo#$pr @ $head_sha"
[ "$mode" = preflight ] && exit 0

mkdir -p "$state_dir"
state_file="$state_dir/pr-${pr}-${head_sha}.json"
label_owned=0

cleanup_label() {
  if [ "$label_owned" -eq 1 ]; then
    gh pr edit "$pr" --repo "$repo" --remove-label "$label" >/dev/null 2>&1 || true
    label_owned=0
  fi
}

lock_dir="${state_file}.lock"

release_controller_lock() {
  rm -f "$lock_dir/pid" 2>/dev/null || true
  rmdir "$lock_dir" 2>/dev/null || true
}

if ! mkdir "$lock_dir" 2>/dev/null; then
  owner_pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
    die "another controller owns state $state_file (pid $owner_pid)"
  fi
  release_controller_lock
  mkdir "$lock_dir" 2>/dev/null || die "unable to acquire controller lock for $state_file"
fi
printf '%s\n' "$$" > "$lock_dir/pid"

cleanup_controller() {
  cleanup_label
  release_controller_lock
}

trap cleanup_controller EXIT
trap 'cleanup_controller; exit 143' INT TERM

write_initial_state() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq -n \
    --arg repo "$repo" --argjson pr "$pr" --arg sha "$head_sha" --arg label_name "$label" \
    --argjson max_sequences "$max_sequences" \
    '{schema_version:2,repo:$repo,pr:$pr,sha:$sha,label:$label_name,max_sequences:$max_sequences,sequence_attempt:1,population_boundary_ids:[],status:"running",runs:[],pending_trigger:null,current_run_id:null,current_run_status:null,errors:[]}' > "$tmp"
  mv "$tmp" "$state_file"
}

if [ ! -f "$state_file" ] || [ "$(jq -r '.status // ""' "$state_file")" = failed ]; then
  write_initial_state
fi

if [ "$(jq -r '.status // ""' "$state_file")" = complete ]; then
  jq -e --arg repo "$repo" --argjson pr "$pr" --arg sha "$head_sha" '
    .repo == $repo and .pr == $pr and .sha == $sha
  ' "$state_file" >/dev/null || die "completed controller state identity does not match this invocation"
  if verify_api_backed_receipt "$receipt" "$head_sha"; then
    :
  else
    status=$?
    [ "$status" -eq 2 ] && exit 2
    exit "$status"
  fi
  completed_verdict="$(jq -r '.verdict' "$state_file")"
  echo "[ci-timing] existing completed receipt verified: verdict=$completed_verdict"
  [ "$completed_verdict" = PASS ] && exit 0
  exit 2
fi

gh_api_json() {
  local endpoint="$1" output reset now delay
  while :; do
    if output="$(gh api -H 'Accept: application/vnd.github+json' "$endpoint" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi

    if grep -qi 'rate limit exceeded' <<<"$output"; then
      reset="$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null || true)"
      now="$(date +%s)"
      delay=60
      if [[ "$reset" =~ ^[0-9]+$ ]] && [ "$reset" -gt "$now" ] && [ $((reset - now + 2)) -lt "$delay" ]; then
        delay=$((reset - now + 2))
      fi
      [ "$delay" -gt 0 ] || delay=1
      echo "[ci-timing] GitHub API rate limited; retrying in ${delay}s" >&2
      sleep "$delay"
      continue
    fi

    printf '%s\n' "$output" >&2
    return 1
  done
}

list_runs() {
  gh_api_json \
    "repos/${repo}/actions/workflows/${workflow}/runs?event=pull_request&branch=${encoded_head_ref}&per_page=100"
}

same_sha_runs() {
  list_runs | jq -c --arg sha "$head_sha" --argjson pr "$pr" '
    [(if type == "array" then .[].workflow_runs[] else .workflow_runs[] end) |
      select(.event == "pull_request" and .head_sha == $sha and any(.pull_requests[]?; .number == $pr))]
  '
}


wait_for_published_head_quiescence() {
  local deadline runs ids previous_ids active observed stable
  deadline=$(( $(date +%s) + run_timeout ))
  previous_ids="[]"
  observed=0
  stable=0
  echo "[ci-timing] waiting for the publication-triggered PR run to quiesce"

  while :; do
    runs="$(same_sha_runs)"
    ids="$(jq -c 'map(.id) | sort' <<<"$runs")"
    active="$(jq '[.[] | select(.status != "completed")] | length' <<<"$runs")"
    [ "$(jq 'length' <<<"$runs")" -gt 0 ] && observed=1

    if [ "$observed" -eq 1 ] && [ "$active" -eq 0 ] && [ "$ids" = "$previous_ids" ]; then
      stable=$((stable + 1))
    else
      stable=0
    fi

    if [ "$stable" -ge 1 ]; then
      echo "[ci-timing] publication-triggered PR run set is quiescent"
      return 0
    fi

    [ "$(date +%s)" -lt "$deadline" ] || return 1
    previous_ids="$ids"
    sleep "$poll_seconds"
  done
}

record_error_and_restart() {
  local reason="$1" attempt="$2" tmp boundary
  boundary="$(same_sha_runs | jq -c 'map(.id)')"
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --arg reason "$reason" --argjson next "$((attempt + 1))" --argjson boundary "$boundary" '
    .errors += [{sequence_attempt:.sequence_attempt,reason:$reason,runs:.runs}] |
    .sequence_attempt=$next | .population_boundary_ids=$boundary | .runs=[] | .pending_trigger=null | .current_run_id=null | .current_run_status=null | .status="running"
  ' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

append_run_state() {
  local run_json="$1" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --argjson run "$run_json" '.runs += [$run] | .pending_trigger=null | .current_run_id=null | .current_run_status=null' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

record_current_run_status() {
  local run_id="$1" run_status="$2" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --argjson id "$run_id" --arg status "$run_status" '
    if .current_run_id == $id then .current_run_status=$status else . end
  ' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

persist_pending_trigger() {
  local before_ids="$1" triggered_at tmp
  triggered_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --argjson before "$before_ids" --arg triggered_at "$triggered_at" '
    .pending_trigger={before_run_ids:$before,triggered_at:$triggered_at,status:"awaiting_run"}
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

adopt_pending_trigger_run() {
  local run_id="$1" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --argjson id "$run_id" '
    .current_run_id=$id | .current_run_status="discovered" |
    .pending_trigger=(.pending_trigger // {}) + {status:"discovered",run_id:$id}
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

wait_for_new_run() {
  local before_ids="$1" candidates
  while :; do
    candidates="$(same_sha_runs | jq -c --argjson before "$before_ids" '[.[] | select((.id as $id | $before | index($id)) == null)]')"
    if [ "$(jq 'length' <<<"$candidates")" -eq 1 ]; then
      jq -r '.[0].id' <<<"$candidates"
      return 0
    fi
    if [ "$(jq 'length' <<<"$candidates")" -gt 1 ]; then
      return 2
    fi
    echo "[ci-timing] owned trigger is awaiting its delayed PR run; polling without relabeling" >&2
    sleep "$poll_seconds"
  done
}

wait_and_validate_run() {
  local run_id="$1" deadline run_json run_status jobs_json summary_count duration result
  deadline=$(( $(date +%s) + run_timeout ))
  while :; do
    run_json="$(gh_api_json "repos/${repo}/actions/runs/${run_id}")"
    run_status="$(jq -r '.status // empty' <<<"$run_json")"
    [ "$run_status" = completed ] && break
    record_current_run_status "$run_id" "$run_status"
    echo "[ci-timing] run $run_id is ${run_status:-unknown}; waiting for terminal completion" >&2
    [ "$(date +%s)" -lt "$deadline" ] || return 4
    sleep "$poll_seconds"
  done
  jobs_json="$(gh_api_json "repos/${repo}/actions/runs/${run_id}/jobs?per_page=100")"
  summary_count="$(jq --arg name "$summary_job" '
    (if type == "array" then [.[].jobs[]] else [.jobs[]] end) |
    [.[] | select(.name == $name)] | length
  ' <<<"$jobs_json")"
  [ "$summary_count" -eq 1 ] || return 2

  result="$(jq -cn --argjson run "$run_json" --argjson pages "$jobs_json" --arg repo "$repo" --arg sha "$head_sha" --arg name "$summary_job" '
    ($pages | (if type == "array" then [.[].jobs[]] else [.jobs[]] end) | [.[] | select(.name == $name)]) as $summary |
    if ($run.event == "pull_request" and $run.head_sha == $sha and $run.run_attempt == 1 and
        $run.status == "completed" and $run.conclusion == "success" and
        $summary[0].status == "completed" and $summary[0].conclusion == "success" and
        $run.run_started_at != null and $summary[0].completed_at != null)
    then {
      id:$run.id,
      url:($run.html_url // ("https://github.com/" + $repo + "/actions/runs/" + ($run.id|tostring))),
      started_at:$run.run_started_at,
      started_epoch:($run.run_started_at|fromdateiso8601),
      summary_completed_at:$summary[0].completed_at,
      summary_completed_epoch:($summary[0].completed_at|fromdateiso8601),
      duration_seconds:(($summary[0].completed_at|fromdateiso8601)-($run.run_started_at|fromdateiso8601)),
      attempt:$run.run_attempt,
      conclusion:$run.conclusion
    } else error("run is not a qualifying successful first-attempt PR sample") end
  ' 2>/dev/null)" || return 3
  [ "$(jq -r '.duration_seconds >= 0' <<<"$result")" = true ] || return 3
  printf '%s\n' "$result"
}

if [ "$published_now" -eq 1 ]; then
  wait_for_published_head_quiescence || die "publication-triggered PR run did not quiesce before sampling"
fi

attempt="$(jq -r '.sequence_attempt' "$state_file")"
while [ "$attempt" -le "$max_sequences" ]; do
  echo "[ci-timing] sequence $attempt/$max_sequences"
  invalid_reason=""
  while [ "$(jq '.runs | length' "$state_file")" -lt "$samples" ]; do
    sample=$(( $(jq '.runs | length' "$state_file") + 1 ))
    current_run_id="$(jq -r '.current_run_id // empty' "$state_file")"
    if [ -n "$current_run_id" ]; then
      run_id="$current_run_id"
      echo "[ci-timing] resuming discovered sample $sample/$samples as run $run_id"
    else
      pending_before_ids="$(jq -c '.pending_trigger.before_run_ids // empty' "$state_file")"
      if [ -n "$pending_before_ids" ]; then
        before_ids="$pending_before_ids"
        echo "[ci-timing] resuming owned delayed trigger for sample $sample/$samples"
      else
        before_ids="$(same_sha_runs | jq '[.[].id]')"
        persist_pending_trigger "$before_ids"
        echo "[ci-timing] triggering sample $sample/$samples"
        gh pr edit "$pr" --repo "$repo" --add-label "$label" >/dev/null
        label_owned=1
      fi
      if ! run_id="$(wait_for_new_run "$before_ids")"; then
        invalid_reason="expected exactly one new same-head PR run after labeling"
        cleanup_label
        break
      fi
      adopt_pending_trigger_run "$run_id"
      cleanup_label
    fi

    if run_result="$(wait_and_validate_run "$run_id")"; then
      :
    else
      validation_exit=$?
      if [ "$validation_exit" -eq 4 ]; then
        die "run $run_id did not reach a terminal state before timeout; persisted current_run_id is retained for resume"
      fi
      invalid_reason="run $run_id was not a qualifying successful first-attempt sample"
      break
    fi
    previous_end="$(jq -r '.runs[-1].summary_completed_epoch // 0' "$state_file")"
    current_start="$(jq -r '.started_epoch' <<<"$run_result")"
    if [ "$previous_end" -gt "$current_start" ]; then
      invalid_reason="run $run_id overlaps the previous selected sample (${current_start} < ${previous_end})"
      break
    fi
    append_run_state "$run_result"
  done

  if [ -z "$invalid_reason" ] && [ "$(jq '.runs | length' "$state_file")" -eq "$samples" ]; then
    break
  fi

  if [ "$attempt" -ge "$max_sequences" ]; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
    jq --arg reason "$invalid_reason" '.errors += [{sequence_attempt:.sequence_attempt,reason:$reason,runs:.runs}] | .status="failed" | .pending_trigger=null | .current_run_id=null | .current_run_status=null' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
    die "sample sequence exhausted after $max_sequences attempt(s): $invalid_reason"
  fi
  echo "[ci-timing] $invalid_reason; restarting sequence $((attempt + 1))/$max_sequences"
  record_error_and_restart "$invalid_reason" "$attempt"
  attempt=$((attempt + 1))
done

runs="$(jq -c '.runs' "$state_file")"
population_boundary_ids="$(jq -c '.population_boundary_ids // []' "$state_file")"
eligible="$(canonical_eligible_run_ids "$head_sha" "$population_boundary_ids")"
selected="$(jq -c 'map(.id)' <<<"$runs")"
[ "$eligible" = "$selected" ] || die "selected run IDs do not equal the complete canonical eligible population"

sorted="$(jq -c '[.[].duration_seconds] | sort' <<<"$runs")"
median="$(jq -r '(.[4] + .[5]) / 2' <<<"$sorted")"
p95="$(jq -r '.[9]' <<<"$sorted")"
verdict=PASS
jq -en --argjson actual "$median" --argjson maximum "$median_max" '$actual <= $maximum' >/dev/null || verdict=FAIL
jq -en --argjson actual "$p95" --argjson maximum "$p95_max" '$actual <= $maximum' >/dev/null || verdict=FAIL

[ "$(grep -c '^CI_TIMING_CURRENT_SOURCE_BEGIN$' "$receipt" 2>/dev/null || true)" -eq 0 ] || die "receipt already contains a current source manifest"
[ "$(grep -c '^CI_TIMING_CURRENT_SOURCE_END$' "$receipt" 2>/dev/null || true)" -eq 0 ] || die "receipt contains a partial current source manifest"
[ "$(grep -c '^CI_TIMING_CURRENT_TABLE_BEGIN$' "$receipt" 2>/dev/null || true)" -eq 0 ] || die "receipt already contains a current timing table"
[ "$(grep -c '^CI_TIMING_CURRENT_TABLE_END$' "$receipt" 2>/dev/null || true)" -eq 0 ] || die "receipt contains a partial current timing table"
section="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-section.XXXXXX")"
next_receipt="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-receipt.XXXXXX")"
trap 'cleanup_controller; rm -f "${section:-}" "${next_receipt:-}"' EXIT
trap 'cleanup_controller; rm -f "${section:-}" "${next_receipt:-}"; exit 143' INT TERM

{
  echo
  echo "## Fresh corrected-head receipt"
  echo
  echo "Corrected implementation SHA: \`$correction_sha\`"
  echo "Preserved subject SHA: \`$preserved_subject_sha\`"
  echo "Measured immutable PR head: \`$head_sha\`"
  echo
  echo "CI_TIMING_CURRENT_TABLE_BEGIN"
  echo "| Sequence | Run ID | Source | Started (UTC) | Duration seconds | Attempt | Result | Exception disposition |"
  echo "| ---: | ---: | --- | --- | ---: | ---: | --- | --- |"
  jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.url) | \(.value.started_at) | \(.value.duration_seconds) | \(.value.attempt) | \(.value.conclusion) | none |"' <<<"$runs"
  echo "CI_TIMING_CURRENT_TABLE_END"
  echo
  echo "Sorted duration seconds: \`$(jq -r 'join(", ")' <<<"$sorted")\`"
  echo
  echo "- Median: (rank 5 + rank 6) / 2 = $median seconds (target <= $median_max)."
  echo "- Nearest-rank p95: rank 10 = $p95 seconds (target <= $p95_max)."
  echo
  echo "| Metric | Target | Observed | Verdict |"
  echo "| --- | ---: | ---: | --- |"
  echo "| Median | <= $median_max | $median | $([ "$(jq -n --argjson a "$median" --argjson b "$median_max" '$a <= $b')" = true ] && echo PASS || echo FAIL) |"
  echo "| p95 | <= $p95_max | $p95 | $([ "$(jq -n --argjson a "$p95" --argjson b "$p95_max" '$a <= $b')" = true ] && echo PASS || echo FAIL) |"
  echo "| Verdict | $verdict | $verdict | $verdict |"
  echo
  echo "CI_TIMING_CURRENT_SOURCE_BEGIN"
  jq -cn --arg repo "$repo" --argjson pr "$pr" --arg sha "$head_sha" --argjson runs "$runs" --argjson boundary "$population_boundary_ids" --argjson median "$median" --argjson p95 "$p95" '{repo:$repo,pr:$pr,sha:$sha,population_boundary_ids:$boundary,runs:$runs,median_seconds:$median,p95_seconds:$p95}'
  echo "CI_TIMING_CURRENT_SOURCE_END"
} > "$section"

cp "$receipt" "$next_receipt"
cat "$section" >> "$next_receipt"
mv "$next_receipt" "$receipt"
verify_current_receipt_shape "$receipt"

tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
jq --arg verdict "$verdict" --argjson median "$median" --argjson p95 "$p95" '.status="complete" | .verdict=$verdict | .median_seconds=$median | .p95_seconds=$p95' "$state_file" > "$tmp" && mv "$tmp" "$state_file"

if [ "$verdict" = PASS ]; then
  echo "[ci-timing] CI timing receipt passed: median=${median}s p95=${p95}s"
  exit 0
fi

echo "[ci-timing] CI timing target missed: median=${median}s p95=${p95}s" >&2
exit 2
