#!/usr/bin/env bash
# Unattended, fail-closed pull-request timing sampler and receipt verifier.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage:
  collect_pr_timing_receipt.sh preflight|run [options]
  collect_pr_timing_receipt.sh verify --receipt PATH

run/preflight options:
  --repo OWNER/REPO --pr N --workflow FILE --summary-job NAME --label NAME
  --samples N --max-sequences N --median-max SECONDS --p95-max SECONDS
  --correction-sha SHA --preserved-subject-sha SHA --receipt PATH
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

manifest_from_receipt() {
  local path="$1"
  awk '$0 == "CI_TIMING_SOURCE_BEGIN" {take=1; next} $0 == "CI_TIMING_SOURCE_END" {take=0} take' "$path"
}

verify_receipt_shape() {
  local path="$1" manifest table_rows manifest_rows
  [ -s "$path" ] || die "receipt is missing or empty: $path"
  [ "$(grep -c '^CI_TIMING_SOURCE_BEGIN$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_SOURCE_BEGIN marker"
  [ "$(grep -c '^CI_TIMING_SOURCE_END$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_SOURCE_END marker"
  [ "$(grep -c '^CI_TIMING_TABLE_BEGIN$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_TABLE_BEGIN marker"
  [ "$(grep -c '^CI_TIMING_TABLE_END$' "$path" || true)" -eq 1 ] || die "receipt must contain one CI_TIMING_TABLE_END marker"

  manifest="$(manifest_from_receipt "$path")"
  jq -e --argjson expected "$samples" '
    (.sha | test("^[0-9a-f]{40}$")) and
    (.runs | type == "array" and length == $expected) and
    (([.runs[].id] | unique | length) == $expected) and
    (all(.runs[]; (.id | type) == "number" and (.duration_seconds | type) == "number" and .duration_seconds >= 0)) and
    ((.median_seconds | type) == "number") and
    ((.p95_seconds | type) == "number")
  ' <<<"$manifest" >/dev/null || die "receipt manifest must contain exactly $samples runs with valid timing data"

  table_rows="$(awk '
    $0 == "CI_TIMING_TABLE_BEGIN" {take=1; next}
    $0 == "CI_TIMING_TABLE_END" {take=0}
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

if [ "$mode" = verify ]; then
  [ -n "$receipt" ] || die "--receipt is required"
  verify_receipt_shape "$receipt"
  echo "[ci-timing] receipt verification passed: $receipt"
  exit 0
fi

case "$mode" in preflight|run) ;; *) usage; exit 64 ;; esac

require_command gh
require_command git
[ -n "$repo" ] || die "--repo is required"
[ -n "$pr" ] || die "--pr is required"
[ -n "$correction_sha" ] || die "--correction-sha is required"
[ -n "$preserved_subject_sha" ] || die "--preserved-subject-sha is required"
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

non_planning_delta="$(git diff --name-only "$preserved_subject_sha..$head_sha" | grep -Ev '^\.planning/' || true)"
[ -z "$non_planning_delta" ] || die "non-planning files changed after preservation: ${non_planning_delta//$'\n'/, }"

pr_json="$(gh pr view "$pr" --repo "$repo" --json state,isDraft,headRefName,headRefOid,labels)"
[ "$(jq -r '.state' <<<"$pr_json")" = OPEN ] || die "PR #$pr is not open"
head_ref="$(jq -r '.headRefName' <<<"$pr_json")"
remote_sha="$(jq -r '.headRefOid' <<<"$pr_json")"
[ -n "$head_ref" ] && [ "$head_ref" != null ] || die "PR head branch is unavailable"

gh label list --repo "$repo" --limit 100 --json name --jq '.[].name' | grep -Fxq "$label" || die "label does not exist: $label"
if jq -e --arg label "$label" 'any(.labels[]?; .name == $label)' <<<"$pr_json" >/dev/null; then
  die "PR already has $label; refusing to take ownership of a pre-existing trigger label"
fi

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
elif [ "$remote_sha" != "$head_sha" ]; then
  die "PR head $remote_sha does not equal local HEAD $head_sha and publication is disabled"
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
trap cleanup_label EXIT INT TERM

write_initial_state() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq -n \
    --arg repo "$repo" --argjson pr "$pr" --arg sha "$head_sha" --arg label "$label" \
    --argjson max_sequences "$max_sequences" \
    '{schema_version:1,repo:$repo,pr:$pr,sha:$sha,label:$label,max_sequences:$max_sequences,sequence_attempt:1,status:"running",runs:[],current_run_id:null,errors:[]}' > "$tmp"
  mv "$tmp" "$state_file"
}

if [ ! -f "$state_file" ] || [ "$(jq -r '.status // ""' "$state_file")" = failed ]; then
  write_initial_state
fi

list_runs() {
  gh api --paginate --slurp -H 'Accept: application/vnd.github+json' \
    "repos/${repo}/actions/workflows/${workflow}/runs?event=pull_request&per_page=100"
}

same_sha_runs() {
  list_runs | jq -c --arg sha "$head_sha" --argjson pr "$pr" '
    [.[].workflow_runs[] |
      select(.event == "pull_request" and .head_sha == $sha and any(.pull_requests[]?; .number == $pr))]
  '
}

record_error_and_restart() {
  local reason="$1" attempt="$2" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --arg reason "$reason" --argjson next "$((attempt + 1))" '
    .errors += [{sequence_attempt:.sequence_attempt,reason:$reason,runs:.runs}] |
    .sequence_attempt=$next | .runs=[] | .current_run_id=null | .status="running"
  ' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

append_run_state() {
  local run_json="$1" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
  jq --argjson run "$run_json" '.runs += [$run] | .current_run_id=null' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

wait_for_new_run() {
  local before_ids="$1" started deadline candidates
  started="$(date +%s)"
  deadline=$((started + creation_timeout))
  while :; do
    candidates="$(same_sha_runs | jq -c --argjson before "$before_ids" '[.[] | select((.id as $id | $before | index($id)) == null)]')"
    if [ "$(jq 'length' <<<"$candidates")" -eq 1 ]; then
      jq -r '.[0].id' <<<"$candidates"
      return 0
    fi
    if [ "$(jq 'length' <<<"$candidates")" -gt 1 ]; then
      return 2
    fi
    [ "$(date +%s)" -lt "$deadline" ] || return 1
    sleep "$poll_seconds"
  done
}

wait_and_validate_run() {
  local run_id="$1" deadline run_json jobs_json summary_count duration result
  deadline=$(( $(date +%s) + run_timeout ))
  while :; do
    run_json="$(gh api -H 'Accept: application/vnd.github+json' "repos/${repo}/actions/runs/${run_id}")"
    [ "$(jq -r '.status' <<<"$run_json")" = completed ] && break
    [ "$(date +%s)" -lt "$deadline" ] || return 1
    sleep "$poll_seconds"
  done
  jobs_json="$(gh api --paginate --slurp -H 'Accept: application/vnd.github+json' "repos/${repo}/actions/runs/${run_id}/jobs?per_page=100")"
  summary_count="$(jq --arg name "$summary_job" '
    (if type == "array" then [.[].jobs[]] else [.jobs[]] end) |
    [.[] | select(.name == $name)] | length
  ' <<<"$jobs_json")"
  [ "$summary_count" -eq 1 ] || return 2

  result="$(jq -cn --argjson run "$run_json" --argjson pages "$jobs_json" --arg sha "$head_sha" --arg name "$summary_job" '
    ($pages | (if type == "array" then [.[].jobs[]] else [.jobs[]] end) | [.[] | select(.name == $name)]) as $summary |
    if ($run.event == "pull_request" and $run.head_sha == $sha and $run.run_attempt == 1 and
        $run.status == "completed" and $run.conclusion == "success" and
        $summary[0].status == "completed" and $summary[0].conclusion == "success" and
        $run.run_started_at != null and $summary[0].completed_at != null)
    then {
      id:$run.id,
      url:($run.html_url // ("https://github.com/" + env.repo + "/actions/runs/" + ($run.id|tostring))),
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

attempt="$(jq -r '.sequence_attempt' "$state_file")"
while [ "$attempt" -le "$max_sequences" ]; do
  echo "[ci-timing] sequence $attempt/$max_sequences"
  invalid_reason=""
  while [ "$(jq '.runs | length' "$state_file")" -lt "$samples" ]; do
    sample=$(( $(jq '.runs | length' "$state_file") + 1 ))
    before_ids="$(same_sha_runs | jq '[.[].id]')"
    echo "[ci-timing] triggering sample $sample/$samples"
    gh pr edit "$pr" --repo "$repo" --add-label "$label" >/dev/null
    label_owned=1
    if ! run_id="$(wait_for_new_run "$before_ids")"; then
      invalid_reason="expected exactly one new same-head PR run after labeling"
      cleanup_label
      break
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
    jq --argjson id "$run_id" '.current_run_id=$id' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
    cleanup_label

    if ! run_result="$(wait_and_validate_run "$run_id")"; then
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
    jq --arg reason "$invalid_reason" '.errors += [{sequence_attempt:.sequence_attempt,reason:$reason,runs:.runs}] | .status="failed" | .current_run_id=null' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
    die "sample sequence exhausted after $max_sequences attempt(s): $invalid_reason"
  fi
  echo "[ci-timing] $invalid_reason; restarting sequence $((attempt + 1))/$max_sequences"
  record_error_and_restart "$invalid_reason" "$attempt"
  attempt=$((attempt + 1))
done

runs="$(jq -c '.runs' "$state_file")"
eligible="$(same_sha_runs | jq -c '[.[] | select(.run_attempt == 1 and .status == "completed" and .conclusion == "success")] | sort_by(.run_started_at, .id) | map(.id)')"
selected="$(jq -c 'map(.id)' <<<"$runs")"
contiguous="$(jq -n --argjson all "$eligible" --argjson selected "$selected" '
  ($selected|length) as $n |
  any(range(0; (($all|length)-$n+1)); . as $i | $all[$i:$i+$n] == $selected)
')"
[ "$contiguous" = true ] || die "selected run IDs are not a contiguous slice of eligible same-head PR runs"

sorted="$(jq -c '[.[].duration_seconds] | sort' <<<"$runs")"
median="$(jq -r '(.[4] + .[5]) / 2' <<<"$sorted")"
p95="$(jq -r '.[9]' <<<"$sorted")"
verdict=PASS
jq -en --argjson actual "$median" --argjson maximum "$median_max" '$actual <= $maximum' >/dev/null || verdict=FAIL
jq -en --argjson actual "$p95" --argjson maximum "$p95_max" '$actual <= $maximum' >/dev/null || verdict=FAIL

[ "$(grep -c '^CI_TIMING_SOURCE_BEGIN$' "$receipt" 2>/dev/null || true)" -eq 0 ] || die "receipt already contains a fresh source manifest"
section="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-section.XXXXXX")"
next_receipt="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-receipt.XXXXXX")"
trap 'cleanup_label; rm -f "${section:-}" "${next_receipt:-}"' EXIT INT TERM

{
  echo
  echo "## Fresh corrected-head receipt"
  echo
  echo "Corrected implementation SHA: \`$correction_sha\`"
  echo "Preserved subject SHA: \`$preserved_subject_sha\`"
  echo "Measured immutable PR head: \`$head_sha\`"
  echo
  echo "CI_TIMING_TABLE_BEGIN"
  echo "| Sequence | Run ID | Source | Started (UTC) | Duration seconds | Attempt | Result | Exception disposition |"
  echo "| ---: | ---: | --- | --- | ---: | ---: | --- | --- |"
  jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.url) | \(.value.started_at) | \(.value.duration_seconds) | \(.value.attempt) | \(.value.conclusion) | none |"' <<<"$runs"
  echo "CI_TIMING_TABLE_END"
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
  echo "CI_TIMING_SOURCE_BEGIN"
  jq -cn --arg sha "$head_sha" --argjson runs "$runs" --argjson median "$median" --argjson p95 "$p95" '{sha:$sha,runs:($runs|map({id,duration_seconds})),median_seconds:$median,p95_seconds:$p95}'
  echo "CI_TIMING_SOURCE_END"
} > "$section"

cp "$receipt" "$next_receipt"
cat "$section" >> "$next_receipt"
mv "$next_receipt" "$receipt"
verify_receipt_shape "$receipt"

tmp="$(mktemp "${TMPDIR:-/tmp}/rindle-ci-timing-state.XXXXXX")"
jq --arg verdict "$verdict" --argjson median "$median" --argjson p95 "$p95" '.status="complete" | .verdict=$verdict | .median_seconds=$median | .p95_seconds=$p95' "$state_file" > "$tmp" && mv "$tmp" "$state_file"

if [ "$verdict" = PASS ]; then
  echo "[ci-timing] CI timing receipt passed: median=${median}s p95=${p95}s"
  exit 0
fi

echo "[ci-timing] CI timing target missed: median=${median}s p95=${p95}s" >&2
exit 2
