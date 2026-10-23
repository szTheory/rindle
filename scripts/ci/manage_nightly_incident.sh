#!/usr/bin/env bash
# Replay immutable Nightly verdict events into one rolling GitHub incident.
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${GH_REPO:?GH_REPO must be set}"
: "${WORKFLOW_NAME:?WORKFLOW_NAME must be set}"
: "${WORKFLOW_REF:?WORKFLOW_REF must be set}"
: "${CURRENT_RUN_ID:?CURRENT_RUN_ID must be set}"
: "${CURRENT_RUN_ATTEMPT:?CURRENT_RUN_ATTEMPT must be set}"
: "${DEFAULT_BRANCH:?DEFAULT_BRANCH must be set}"
: "${REMOTE_MAIN_SHA:?REMOTE_MAIN_SHA must be set}"

incident_label="${INCIDENT_LABEL:-nightly-failure}"
incident_title="${INCIDENT_TITLE:-Nightly CI failure}"
fetch_attempts="${NIGHTLY_REPLAY_FETCH_ATTEMPTS:-5}"
max_restarts="${NIGHTLY_REPLAY_MAX_RESTARTS:-100}"
sleep_seconds="${NIGHTLY_REPLAY_SLEEP_SECONDS:-2}"
visibility_reads="${NIGHTLY_REPLAY_VISIBILITY_READS:-15}"

fail() {
  echo "[manage-nightly-incident] $1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
[[ "${GH_REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "invalid GH_REPO"
[ "${WORKFLOW_NAME}" = Nightly ] || fail "unexpected WORKFLOW_NAME"
[ "${incident_label}" = nightly-failure ] || fail "unexpected incident label"
[ "${incident_title}" = "Nightly CI failure" ] || fail "unexpected incident title"
[[ "${CURRENT_RUN_ID}" =~ ^[1-9][0-9]{0,19}$ ]] || fail "invalid CURRENT_RUN_ID"
[[ "${CURRENT_RUN_ATTEMPT}" =~ ^[1-9][0-9]{0,9}$ ]] || fail "invalid CURRENT_RUN_ATTEMPT"
[[ "${DEFAULT_BRANCH}" =~ ^[A-Za-z0-9._/-]{1,100}$ ]] || fail "invalid DEFAULT_BRANCH"
[[ "${REMOTE_MAIN_SHA}" =~ ^[0-9a-f]{40}$ ]] || fail "invalid REMOTE_MAIN_SHA"
[[ "${fetch_attempts}" =~ ^[1-9][0-9]{0,2}$ ]] || fail "invalid fetch attempt bound"
[[ "${max_restarts}" =~ ^[1-9][0-9]{0,3}$ ]] || fail "invalid replay restart bound"
[[ "${sleep_seconds}" =~ ^[0-9]{1,2}$ ]] || fail "invalid replay sleep"
[[ "${visibility_reads}" =~ ^[1-9][0-9]?$ ]] || fail "invalid replay visibility reads"

expected_workflow_ref="${GH_REPO}/.github/workflows/nightly.yml@refs/heads/${DEFAULT_BRANCH}"
[ "${WORKFLOW_REF}" = "${expected_workflow_ref}" ] || fail "unexpected WORKFLOW_REF"

workspace="$(mktemp -d)"
trap 'rm -rf "${workspace}"' EXIT
runs_file="${workspace}/runs.json"
artifacts_file="${workspace}/artifacts.json"
events_file="${workspace}/events.json"
checkpoint_file="${workspace}/checkpoint.json"
checkpoint_path="${CHECKPOINT_OUTPUT_PATH:-}"
checkpoint_run=0
checkpoint_attempt=0
checkpoint_chain="$(printf '0%.0s' {1..64})"
checkpoint_event_digest=""
checkpoint_issue_number=""
checkpoint_issue_state=""
checkpoint_issue_digest=""
genesis_run=0
genesis_attempt=0

[[ -n "${checkpoint_path}" ]] || fail "CHECKPOINT_OUTPUT_PATH must be set"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'
  fi
}

event_digest() {
  jq -cS . "$1" >"${workspace}/event.canonical"
  sha256_file "${workspace}/event.canonical"
}

require_expiry_margin() {
  local expires_at="$1" now_epoch expires_epoch
  now_epoch="$(date -u +%s)"
  expires_epoch="$(jq -nr --arg timestamp "${expires_at}" '$timestamp | fromdateiso8601')" ||
    fail "artifact expiry timestamp is invalid"
  [[ "${now_epoch}" =~ ^[0-9]+$ && "${expires_epoch}" =~ ^[0-9]+$ ]] || fail "invalid artifact clock"
  ((expires_epoch - now_epoch >= 3600)) || fail "retained replay evidence is within one hour of expiry"
}
fetch_runs() {
  local pages base_file row run_id max_attempt attempt detail
  pages="$(${GH_CLI:-gh} api --paginate --slurp \
    "repos/${GH_REPO}/actions/workflows/nightly.yml/runs?event=schedule&per_page=100")"
  jq -e '
    type == "array" and length > 0 and
    all(.[]; type == "object" and (.workflow_runs | type == "array"))
  ' >/dev/null <<<"${pages}" || fail "invalid workflow-run inventory"
  base_file="${workspace}/base-runs.json"
  jq -cS '[.[].workflow_runs[]]' <<<"${pages}" >"${base_file}"

  jq -e --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" \
    --arg sha "${REMOTE_MAIN_SHA}" --arg branch "${DEFAULT_BRANCH}" '
      all(.[];
        type == "object" and
        (.id | type == "number" and . > 0 and floor == .) and
        (.run_attempt | type == "number" and . > 0 and floor == .) and
        (.event == "schedule") and
        (.status | IN("queued", "in_progress", "completed")) and
        ((.conclusion == null) or (.conclusion | IN("success", "failure", "cancelled", "skipped", "timed_out", "action_required", "neutral", "stale"))) and
        (.head_sha | type == "string" and test("^[0-9a-f]{40}$")) and
        (.head_branch | type == "string") and
        (.html_url | type == "string") and
        (.name == "Nightly") and
        (.path == ".github/workflows/nightly.yml")
      ) and
      ([.[].id] | length == (unique | length))
    ' "${base_file}" >/dev/null || fail "workflow-run inventory was malformed or duplicated"

  printf '[]\n' >"${runs_file}"
  while IFS= read -r row; do
    run_id="$(jq -r .id <<<"${row}")"
    max_attempt="$(jq -r .run_attempt <<<"${row}")"
    for ((attempt = 1; attempt <= max_attempt; attempt++)); do
      detail="$(${GH_CLI:-gh} api "repos/${GH_REPO}/actions/runs/${run_id}/attempts/${attempt}")" ||
        fail "workflow attempt lookup failed for ${run_id}/${attempt}"
      jq -e --argjson id "${run_id}" --argjson attempt "${attempt}" \
        '.id == $id and .run_attempt == $attempt and .event == "schedule" and
         .name == "Nightly" and .path == ".github/workflows/nightly.yml"' \
        >/dev/null <<<"${detail}" || fail "workflow attempt identity mismatch for ${run_id}/${attempt}"
      jq -cS --argjson id "${run_id}" --argjson attempt "${attempt}" \
        '. + {id:$id,run_attempt:$attempt}' <<<"${detail}" |
        jq -s -cS --slurpfile existing "${runs_file}" '$existing[0] + .' >"${workspace}/runs.next"
      mv "${workspace}/runs.next" "${runs_file}"
    done
  done < <(jq -c '.[]' "${base_file}")

  jq -e --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" \
    --arg sha "${REMOTE_MAIN_SHA}" --arg branch "${DEFAULT_BRANCH}" '
      ([.[] | [.id, .run_attempt]] | length == (unique | length)) and
      ([.[] | select(.id == $high and .run_attempt == $attempt and .head_sha == $sha and .head_branch == $branch)] | length == 1)
    ' "${runs_file}" >/dev/null || fail "workflow-run inventory does not authenticate the current high-watermark"
}

fetch_artifacts() {
  local pages
  pages="$(${GH_CLI:-gh} api --paginate --slurp \
    "repos/${GH_REPO}/actions/artifacts?per_page=100")"
  jq -e '
    type == "array" and length > 0 and
    all(.[]; type == "object" and (.artifacts | type == "array"))
  ' >/dev/null <<<"${pages}" || fail "invalid artifact inventory"
  jq -cS '[.[].artifacts[]]' <<<"${pages}" >"${artifacts_file}"
}

# Genesis: scheduled runs before the first verdict artifact predate the verdict
# log and cannot be replayed. Without an authenticated checkpoint, the earliest
# verdict artifact (retained or expired, or the current attempt when none is
# visible yet) starts the replay cursor; earlier runs are pre-genesis legacy.
compute_genesis() {
  local genesis
  if [ "${checkpoint_run}" -ne 0 ]; then
    genesis_run=0
    genesis_attempt=0
    return 0
  fi
  genesis="$(jq -r --arg prefix 'nightly-incident-verdict-' \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" '
      [ .[] | select(.name | startswith($prefix)) |
        (.name | capture("^nightly-incident-verdict-(?<run>[1-9][0-9]{0,19})-(?<attempt>[1-9][0-9]{0,9})$")) |
        [(.run | tonumber), (.attempt | tonumber)] ] + [[$high, $high_attempt]] |
      min | "\(.[0]) \(.[1])"
    ' "${artifacts_file}")" || fail "malformed canonical artifact name"
  read -r genesis_run genesis_attempt <<<"${genesis}"
}

prepare_event_index() {
  jq -e '
    def retention_ok:
      if ((.name | startswith("nightly-incident-verdict-") or startswith("nightly-incident-replay-checkpoint-")) | not) or .expired then true
      else
        (.created_at | type == "string") and (.expires_at | type == "string") and
        ((.expires_at | fromdateiso8601) - (.created_at | fromdateiso8601) >= 1209300)
      end;
    all(.[];
      type == "object" and
      (.id | type == "number" and . > 0 and floor == .) and
      (.name | type == "string") and
      (.expired | type == "boolean") and
      (.workflow_run | type == "object") and
      (.workflow_run.id | type == "number" and . > 0 and floor == .) and
      retention_ok
    ) and
    ([.[].id] | length == (unique | length))
  ' "${artifacts_file}" >/dev/null || fail "invalid artifact metadata"

  # Expired evidence is tolerated only strictly before the authenticated cursor.
  jq -e --arg prefix 'nightly-incident-verdict-' \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" \
    --argjson cursor "${checkpoint_run}" --argjson cursor_attempt "${checkpoint_attempt}" '
      [ .[] |
        select(.name | startswith($prefix)) |
        (.name | capture("^nightly-incident-verdict-(?<run>[1-9][0-9]{0,19})-(?<attempt>[1-9][0-9]{0,9})$")) as $identity |
        ($identity.run | tonumber) as $run |
        ($identity.attempt | tonumber) as $attempt |
        select($run < $high or ($run == $high and $attempt <= $high_attempt)) |
        select(.expired == true) |
        ($run < $cursor or ($run == $cursor and $attempt <= $cursor_attempt))
      ] | all
    ' "${artifacts_file}" >/dev/null || fail "expired verdict artifact inside authenticated replay epoch"

  jq -cS --arg prefix 'nightly-incident-verdict-' \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" \
    --argjson cursor "${checkpoint_run}" --argjson cursor_attempt "${checkpoint_attempt}" '
      [
        .[] |
        select(.expired == false) |
        select(.name | startswith($prefix)) |
        (.name | capture("^nightly-incident-verdict-(?<run>[1-9][0-9]{0,19})-(?<attempt>[1-9][0-9]{0,9})$")) as $identity |
        {
          artifact_id:.id,
          name:.name,
          expires_at:.expires_at,
          workflow_run_id:.workflow_run.id,
          run_id:($identity.run | tonumber),
          run_attempt:($identity.attempt | tonumber)
        } |
        select(.run_id < $high or (.run_id == $high and .run_attempt <= $high_attempt)) |
        select(.run_id > $cursor or (.run_id == $cursor and .run_attempt > $cursor_attempt))
      ]
  ' "${artifacts_file}" >"${workspace}/event-index.json" || fail "malformed canonical artifact name"

  while IFS= read -r expiry; do
    require_expiry_margin "${expiry}"
  done < <(jq -r '.[].expires_at' "${workspace}/event-index.json")

  jq -e '
    all(.[]; .workflow_run_id == .run_id) and
    (group_by([.run_id, .run_attempt]) | all(.[]; length == 1))
  ' "${workspace}/event-index.json" >/dev/null || fail "duplicate or mismatched canonical event artifact"

  compute_genesis
  jq -cS --arg branch "${DEFAULT_BRANCH}" \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" \
    --argjson cursor "${checkpoint_run}" --argjson cursor_attempt "${checkpoint_attempt}" \
    --argjson genesis "${genesis_run}" --argjson genesis_attempt "${genesis_attempt}" '
      [
        .[] |
        select((.id < $high or (.id == $high and .run_attempt <= $high_attempt)) and .head_branch == $branch) |
        select(.id > $genesis or (.id == $genesis and .run_attempt >= $genesis_attempt)) |
        select((.id > $cursor or (.id == $cursor and .run_attempt > $cursor_attempt)) and .head_branch == $branch) |
        select(.status == "completed" or .id == $high) |
        {run_id:.id,run_attempt:.run_attempt,event:.event,status:.status,conclusion:.conclusion,sha:.head_sha,branch:.head_branch,url:.html_url,name:.name,path:.path}
      ] | sort_by(.run_id, .run_attempt)
    ' "${runs_file}" >"${workspace}/relevant-runs.json"

  jq -e 'length > 0' "${workspace}/relevant-runs.json" >/dev/null || fail "no relevant scheduled runs"
  jq -e --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" '
    [ .[] | select(.run_id == $high and .run_attempt == $attempt) ] | length == 1
  ' "${workspace}/relevant-runs.json" >/dev/null || fail "current high-watermark is not relevant"

  if ! jq -e --slurpfile artifacts "${workspace}/event-index.json" '
    ([.[] as $run |
      [$artifacts[0][] | select(.run_id == $run.run_id and .run_attempt == $run.run_attempt)] | length == 1
    ] | all) and
    ([$artifacts[0][] as $artifact |
      [.[] | select(.run_id == $artifact.run_id and .run_attempt == $artifact.run_attempt)] | length == 1
    ] | all)
  ' "${workspace}/relevant-runs.json" >/dev/null; then
    return 1
  fi

  if [ "$(jq length "${workspace}/event-index.json")" -gt 0 ]; then
    jq -e --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" '
      sort_by(.run_id, .run_attempt) | last | .run_id == $high and .run_attempt == $attempt
    ' "${workspace}/event-index.json" >/dev/null || fail "artifact high-watermark does not match current run"
  elif [ "${checkpoint_run}" -ne "${CURRENT_RUN_ID}" ] || [ "${checkpoint_attempt}" -ne "${CURRENT_RUN_ATTEMPT}" ]; then
    fail "empty replay epoch does not end at current scheduled attempt"
  fi
}

load_checkpoint() {
  local candidates selected producer_run producer_attempt path digest expected_event
  candidates="${workspace}/checkpoint-candidates.json"
  jq -cS --arg prefix 'nightly-incident-replay-checkpoint-' '
    [ .[] | select(.name | startswith($prefix)) |
      (.name | capture("^nightly-incident-replay-checkpoint-(?<run>[1-9][0-9]{0,19})-(?<attempt>[1-9][0-9]{0,9})$")) as $identity |
      {id:.id,name:.name,expired:.expired,expires_at:.expires_at,workflow_run_id:.workflow_run.id,
       run_id:($identity.run|tonumber),run_attempt:($identity.attempt|tonumber)}
    ] | sort_by(.run_id,.run_attempt)
  ' "${artifacts_file}" >"${candidates}" || fail "malformed checkpoint artifact name"
  jq -e 'all(.[]; .workflow_run_id == .run_id) and
    (group_by([.run_id,.run_attempt]) | all(.[]; length == 1))' "${candidates}" >/dev/null ||
    fail "duplicate or mismatched checkpoint artifact"
  selected="$(jq -c --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" \
    '[.[] | select((.run_id < $high or (.run_id == $high and .run_attempt < $attempt)) and .expired == false)] | last // empty' "${candidates}")"
  [ -n "${selected}" ] || return 0

  require_expiry_margin "$(jq -r .expires_at <<<"${selected}")"

  producer_run="$(jq -r .run_id <<<"${selected}")"
  producer_attempt="$(jq -r .run_attempt <<<"${selected}")"
  path="${workspace}/checkpoint-download"
  mkdir -p "${path}"
  ${GH_CLI:-gh} run download "${producer_run}" --repo "${GH_REPO}" \
    --name "$(jq -r .name <<<"${selected}")" --dir "${path}" >/dev/null || fail "checkpoint artifact download failed"
  [ -f "${path}/nightly-incident-checkpoint.json" ] || fail "checkpoint artifact omitted canonical JSON"
  cp "${path}/nightly-incident-checkpoint.json" "${checkpoint_file}"

  jq -e --arg repository "${GH_REPO}" --arg workflow_ref "${expected_workflow_ref}" \
    --argjson producer_run "${producer_run}" --argjson producer_attempt "${producer_attempt}" '
      type == "object" and
      (keys|sort) == ["chain_digest","event_digest","issue_digest","issue_number","issue_state","last_run_attempt","last_run_id","previous_chain_digest","repository","schema","workflow_ref"] and
      .schema == "rindle-nightly-incident-checkpoint-v1" and
      .repository == $repository and .workflow_ref == $workflow_ref and
      .last_run_id == $producer_run and .last_run_attempt == $producer_attempt and
      (.event_digest | type == "string" and test("^[0-9a-f]{64}$")) and
      (.chain_digest | type == "string" and test("^[0-9a-f]{64}$")) and
      (.previous_chain_digest | type == "string" and test("^[0-9a-f]{64}$")) and
      (.issue_digest | type == "string" and test("^[0-9a-f]{64}$")) and
      ((.issue_number == null) or (.issue_number | type == "number" and . > 0 and floor == .)) and
      ((.issue_state == null) or (.issue_state | IN("OPEN","CLOSED"))) and
      ((.issue_number == null) == (.issue_state == null))
    ' "${checkpoint_file}" >/dev/null || fail "checkpoint payload failed exact artifact/run authentication"

  local producer_row producer_sha producer_url
  producer_row="$(jq -c --argjson id "${producer_run}" --argjson attempt "${producer_attempt}" \
    --arg branch "${DEFAULT_BRANCH}" \
    '[.[] | select(.id == $id and .run_attempt == $attempt and .event == "schedule" and .name == "Nightly" and .path == ".github/workflows/nightly.yml" and .head_branch == $branch)] | if length == 1 then .[0] else empty end' \
    "${runs_file}")"
  [ -n "${producer_row}" ] || fail "checkpoint producer is absent from authenticated workflow attempts"
  producer_sha="$(jq -r .head_sha <<<"${producer_row}")"
  producer_url="$(jq -r .html_url <<<"${producer_row}")"

  # The checkpoint's own attempt verdict artifact must still be retained and match its digest.
  expected_event="$(jq -r --argjson run "${producer_run}" --argjson attempt "${producer_attempt}" \
    '[.[] | select(.name == ("nightly-incident-verdict-" + ($run|tostring) + "-" + ($attempt|tostring)) and .expired == false and .workflow_run.id == $run)] | if length == 1 then .[0].name else empty end' "${artifacts_file}")"
  [ -n "${expected_event}" ] || fail "checkpoint anchor verdict artifact is missing or expired"
  require_expiry_margin "$(jq -r --arg name "${expected_event}" '[.[] | select(.name == $name)][0].expires_at' "${artifacts_file}")"
  path="${workspace}/checkpoint-event"
  mkdir -p "${path}"
  ${GH_CLI:-gh} run download "${producer_run}" --repo "${GH_REPO}" \
    --name "${expected_event}" --dir "${path}" >/dev/null || fail "checkpoint anchor verdict download failed"
  [ -f "${path}/nightly-incident-verdict.json" ] || fail "checkpoint anchor verdict is malformed"
  jq -e --arg repository "${GH_REPO}" --arg workflow_ref "${expected_workflow_ref}" \
    --arg ref "refs/heads/${DEFAULT_BRANCH}" --arg sha "${producer_sha}" --arg url "${producer_url}" \
    --argjson run "${producer_run}" --argjson attempt "${producer_attempt}" '
    type == "object" and
    (keys | sort) == ["event","ref","repository","run_attempt","run_id","schema","sha","url","verdict","workflow_name","workflow_ref"] and
    .schema == "rindle-nightly-incident-verdict-v1" and .repository == $repository and
    .workflow_name == "Nightly" and .workflow_ref == $workflow_ref and .event == "schedule" and
    .run_id == $run and .run_attempt == $attempt and .sha == $sha and .ref == $ref and .url == $url and
    (.verdict | type == "object") and
    (.verdict | keys | sort) == ["errors","jobs","verdict"] and
    (.verdict.verdict | IN("red","green")) and
    (.verdict.jobs | type == "array" and length > 0) and
    all(.verdict.jobs[]; type == "object" and (.name | type == "string") and (.status | IN("passed","not-run","failed"))) and
    (.verdict.errors | type == "array")
    ' \
    "${path}/nightly-incident-verdict.json" >/dev/null || fail "checkpoint anchor identity mismatch"
  digest="$(event_digest "${path}/nightly-incident-verdict.json")"
  [ "${digest}" = "$(jq -r .event_digest "${checkpoint_file}")" ] || fail "checkpoint event digest mismatch"

  jq -cS '{previous_chain_digest,last_run_id,last_run_attempt,event_digest,issue_digest,issue_number,issue_state}' \
    "${checkpoint_file}" >"${workspace}/checkpoint-chain-input.json"
  digest="$(sha256_file "${workspace}/checkpoint-chain-input.json")"
  [ "${digest}" = "$(jq -r .chain_digest "${checkpoint_file}")" ] || fail "checkpoint chain digest mismatch"

  checkpoint_run="${producer_run}"
  checkpoint_attempt="${producer_attempt}"
  checkpoint_chain="$(jq -r .chain_digest "${checkpoint_file}")"
  checkpoint_event_digest="$(jq -r .event_digest "${checkpoint_file}")"
  checkpoint_issue_number="$(jq -r '.issue_number // empty' "${checkpoint_file}")"
  checkpoint_issue_state="$(jq -r '.issue_state // empty' "${checkpoint_file}")"
  checkpoint_issue_digest="$(jq -r .issue_digest "${checkpoint_file}")"
}

# The checkpoint digest covers the issue history as it stood when the checkpoint
# was written. A later run can mutate (open, comment, close) and then fail before
# writing its own checkpoint; that content must not invalidate the checkpoint, or
# the replay chain wedges permanently. So the comparison drops issues and comments
# whose mutation marker is later than the checkpoint cursor. Those markers are
# still checked against authenticated verdict events by derive_intent, so a forged
# or wrong-action marker fails there, and any edit to pre-cursor history still
# changes the digest.
validate_checkpoint_issue() {
  [ "${checkpoint_run}" -ne 0 ] || return 0
  local issues="${workspace}/checkpoint-issues.json"
  local scoped="${workspace}/checkpoint-issues.scoped" digest
  inventory "${issues}"
  jq --argjson run "${checkpoint_run}" --argjson attempt "${checkpoint_attempt}" '
    def post_cursor_actions:
      [scan("nightly-mutation:(open|update|close):([1-9][0-9]{0,19}):([1-9][0-9]{0,9})") |
        select((.[1] | tonumber) > $run or ((.[1] | tonumber) == $run and (.[2] | tonumber) > $attempt)) | .[0]];
    def post_cursor: post_cursor_actions | length > 0;
    # A later close mutation flips the state of an issue that predates the
    # cursor; project the issue back to the open state it had at the checkpoint.
    map(select(.body | post_cursor | not) |
      if any(.comments[].body; post_cursor_actions | index("close")) then .state = "OPEN" else . end |
      .comments |= map(select(.body | post_cursor | not)))
  ' "${issues}" >"${scoped}"
  jq -cS . "${scoped}" >"${workspace}/checkpoint-issues.canonical"
  digest="$(sha256_file "${workspace}/checkpoint-issues.canonical")"
  [ "${digest}" = "${checkpoint_issue_digest}" ] || fail "incident issue history differs from authenticated checkpoint"
  if [ -n "${checkpoint_issue_number}" ]; then
    jq -e --argjson number "${checkpoint_issue_number}" --arg state "${checkpoint_issue_state}" \
      '[.[] | select(.number == $number and .state == $state)] | length == 1' "${scoped}" >/dev/null ||
      fail "checkpoint incident number/state is absent from issue history"
  elif [ "$(jq length "${scoped}")" -ne 0 ]; then
    fail "checkpoint expected no incident, but issue history is non-empty"
  fi
}

authenticate_events() {
  : >"${events_file}"
  while IFS= read -r row; do
    local run_id run_attempt artifact_name download_dir event_path
    run_id="$(jq -r .run_id <<<"${row}")"
    run_attempt="$(jq -r .run_attempt <<<"${row}")"
    artifact_name="$(jq -r --argjson run "${run_id}" --argjson attempt "${run_attempt}" \
      '.[] | select(.run_id == $run and .run_attempt == $attempt) | .name' \
      "${workspace}/event-index.json")"
    download_dir="${workspace}/download-${run_id}-${run_attempt}"
    mkdir -p "${download_dir}"
    ${GH_CLI:-gh} run download "${run_id}" --repo "${GH_REPO}" \
      --name "${artifact_name}" --dir "${download_dir}" >/dev/null
    event_path="${download_dir}/nightly-incident-verdict.json"
    [ -f "${event_path}" ] || fail "artifact ${artifact_name} omitted canonical event JSON"

    jq -e \
      --arg repository "${GH_REPO}" \
      --arg workflow_name "${WORKFLOW_NAME}" \
      --arg workflow_ref "${expected_workflow_ref}" \
      --argjson run_id "${run_id}" \
      --argjson run_attempt "${run_attempt}" \
      --arg sha "$(jq -r .sha <<<"${row}")" \
      --arg ref "refs/heads/${DEFAULT_BRANCH}" \
      --arg url "$(jq -r .url <<<"${row}")" '
        type == "object" and
        (keys | sort) == ["event","ref","repository","run_attempt","run_id","schema","sha","url","verdict","workflow_name","workflow_ref"] and
        .schema == "rindle-nightly-incident-verdict-v1" and
        .repository == $repository and
        .workflow_name == $workflow_name and
        .workflow_ref == $workflow_ref and
        .event == "schedule" and
        .run_id == $run_id and
        .run_attempt == $run_attempt and
        .sha == $sha and
        .ref == $ref and
        .url == $url and
        (.verdict | type == "object") and
        (.verdict | keys | sort) == ["errors","jobs","verdict"] and
        (.verdict.verdict | IN("red", "green")) and
        (.verdict.jobs | type == "array" and length > 0) and
        all(.verdict.jobs[]; type == "object" and (.name | type == "string") and (.status | IN("passed", "not-run", "failed"))) and
        (.verdict.errors | type == "array")
      ' "${event_path}" >/dev/null || fail "event ${run_id}/${run_attempt} failed run/artifact authentication"
    jq -cS . "${event_path}" >>"${events_file}"
  done < <(jq -c '.[]' "${workspace}/relevant-runs.json")

  jq -s -cS 'sort_by(.run_id, .run_attempt)' "${events_file}" >"${workspace}/events.sorted"
  mv "${workspace}/events.sorted" "${events_file}"
}

inventory() {
  local output="$1"
  ${GH_CLI:-gh} issue list --repo "${GH_REPO}" --state all --label "${incident_label}" \
    --limit 100 --json number,title,state,body,comments >"${output}"
  jq -e --arg title "${incident_title}" '
    type == "array" and
    all(.[];
      type == "object" and
      (.number | type == "number" and . > 0 and floor == .) and
      .title == $title and
      (.state | IN("OPEN", "CLOSED")) and
      (.body | type == "string") and
      (.comments | type == "array") and
      all(.comments[]; type == "object" and (.body | type == "string"))
    ) and
    ([.[] | select(.state == "OPEN")] | length <= 1)
  ' "${output}" >/dev/null || fail "invalid or competing exact-label incident inventory"

  jq -e '
    [
      .[] as $issue |
      ([{issue:$issue.number,text:$issue.body}] + [$issue.comments[] | {issue:$issue.number,text:.body}])[] |
      . as $source |
      ($source.text | scan("nightly-mutation:(?:open|update|close):[1-9][0-9]{0,19}:[1-9][0-9]{0,9}")) as $marker |
      {marker:$marker,issue:$source.issue}
    ] | group_by(.marker) | all(.[]; length == 1)
  ' "${output}" >/dev/null || fail "duplicate mutation marker ownership"
}

derive_intent() {
  local inventory_file="$1" intent_file="$2"
  local marker_file="${workspace}/markers" open_count logical_open missing=false
  local first_run first_attempt logical_issue="" pending_issue="" pending_state=""
  jq -r '[.[] | .body, .comments[].body] | .[] | scan("nightly-mutation:(?:open|update|close):[1-9][0-9]{0,19}:[1-9][0-9]{0,9}")' \
    "${inventory_file}" | sort >"${marker_file}"
  open_count="$(jq '[.[] | select(.state == "OPEN")] | length' "${inventory_file}")"
  logical_open=false
  if [ "${checkpoint_run}" -gt 0 ]; then
    # validate_checkpoint_issue excludes post-cursor content from the checkpoint
    # digest, so every such marker must name an authenticated replay event.
    jq -e -R -s --argjson run "${checkpoint_run}" --argjson attempt "${checkpoint_attempt}" \
      --slurpfile events "${events_file}" '
        split("\n") | map(select(length > 0) | split(":") | {run:(.[2] | tonumber), attempt:(.[3] | tonumber)}) |
        map(select(.run > $run or (.run == $run and .attempt > $attempt))) |
        all(.[]; . as $marker | $events[0] | any(.[]; .run_id == $marker.run and .run_attempt == $marker.attempt))
      ' "${marker_file}" >/dev/null || fail "post-checkpoint mutation marker has no authenticated verdict event"
    if [ "${checkpoint_issue_state}" = OPEN ]; then
      logical_open=true
      logical_issue="${checkpoint_issue_number}"
    fi
  elif [ "$(jq length "${events_file}")" -gt 0 ]; then
    first_run="$(jq -r '.[0].run_id' "${events_file}")"
    first_attempt="$(jq -r '.[0].run_attempt' "${events_file}")"
    if { [ ! -s "${marker_file}" ] && [ "${open_count}" -eq 1 ]; } ||
       grep -Eq "^nightly-mutation:(update|close):${first_run}:${first_attempt}$" "${marker_file}"; then
      logical_open=true
      logical_issue="$(jq -r '[.[] | select(.state == "OPEN")][0].number // empty' "${inventory_file}")"
      if [ -z "${logical_issue}" ]; then
        logical_issue="$(jq -r --arg update "nightly-mutation:update:${first_run}:${first_attempt}" \
          --arg close "nightly-mutation:close:${first_run}:${first_attempt}" \
          '.[] | select([.body, .comments[].body | scan("nightly-mutation:(?:open|update|close):[1-9][0-9]{0,19}:[1-9][0-9]{0,9}")] |
            index($update) != null or index($close) != null) | .number' "${inventory_file}")"
      fi
    fi
  fi
  printf 'null\n' >"${intent_file}"

  while IFS= read -r event; do
    local verdict run_id run_attempt action marker same_event_count
    verdict="$(jq -r .verdict.verdict <<<"${event}")"
    run_id="$(jq -r .run_id <<<"${event}")"
    run_attempt="$(jq -r .run_attempt <<<"${event}")"
    if [ "${verdict}" = red ]; then
      if [ "${logical_open}" = true ]; then action=update; else action=open; fi
    elif [ "${logical_open}" = true ]; then
      action=close
    else
      action=noop
    fi
    marker="nightly-mutation:${action}:${run_id}:${run_attempt}"
    same_event_count="$(awk -F: -v id="${run_id}" -v attempt="${run_attempt}" '$3 == id && $4 == attempt {count++} END {print count+0}' "${marker_file}")"

    if [ "${action}" = noop ]; then
      [ "${same_event_count}" -eq 0 ] || fail "no-op event has a forbidden mutation marker"
      continue
    fi
    if grep -Fqx "${marker}" "${marker_file}"; then
      [ "${same_event_count}" -eq 1 ] || fail "event owns an unexpected mutation marker"
      [ "${missing}" = false ] || fail "incident history applies a later event before an earlier event"
      local owner
      owner="$(jq -r --arg marker "${marker}" \
        '.[] | select([.body, .comments[].body | scan("nightly-mutation:(?:open|update|close):[1-9][0-9]{0,19}:[1-9][0-9]{0,9}")] |
          index($marker) != null) | .number' "${inventory_file}")"
      if [ "${action}" = open ]; then
        logical_issue="${owner}"
      else
        [ "${owner}" = "${logical_issue}" ] || fail "mutation marker belongs to a different incident"
      fi
    else
      [ "${same_event_count}" -eq 0 ] || fail "event owns the wrong mutation marker"
      if [ "${missing}" = false ]; then
        if [ "${action}" != open ]; then
          [[ "${logical_issue}" =~ ^[1-9][0-9]*$ ]] || fail "authenticated incident target is absent"
          pending_issue="${logical_issue}"
          pending_state="$(jq -r --argjson number "${pending_issue}" \
            '.[] | select(.number == $number) | .state' "${inventory_file}")"
          [[ "${pending_state}" = OPEN || "${pending_state}" = CLOSED ]] || fail "authenticated incident target is absent"
        fi
        jq -cn --arg action "${action}" --arg marker "${marker}" --argjson event "${event}" \
          --argjson open "${open_count}" --arg issue "${pending_issue}" --arg state "${pending_state}" \
          '{action:$action,marker:$marker,event:$event,open_count:$open,issue_number:$issue,issue_state:$state}' >"${intent_file}"
        missing=true
      fi
    fi
    case "${action}" in
      open) logical_open=true; [ "${missing}" = false ] || logical_issue="" ;;
      update) logical_open=true ;;
      close) logical_open=false; logical_issue="" ;;
    esac
  done < <(jq -c '.[]' "${events_file}")

  # An operator can close an issue before replay catches up. Historical updates
  # may still be appended when a later green event closes that same incident.
  # A still-red incident requires explicit reconciliation, never a retry loop.
  if [ "${pending_state}" = CLOSED ] && [ "${logical_open}" = true ] &&
     [ "${logical_issue}" = "${pending_issue}" ]; then
    fail "incident closed outside authenticated history while its latest verdict is red"
  fi

  if [ "${missing}" = false ]; then
    if { [ "${logical_open}" = true ] && [ "${open_count}" -ne 1 ]; } ||
       { [ "${logical_open}" = false ] && [ "${open_count}" -ne 0 ]; }; then
      fail "incident state disagrees with authenticated mutation history"
    fi
  fi
}

write_checkpoint() {
  local issue_file="$1" event_digest_value issue_digest_value issue_number issue_state previous
  if [ "$(jq length "${events_file}")" -gt 0 ]; then
    jq 'sort_by(.run_id,.run_attempt) | last' "${events_file}" >"${workspace}/last-event.json"
    event_digest_value="$(event_digest "${workspace}/last-event.json")"
  else
    event_digest_value="${checkpoint_event_digest}"
  fi
  [ -n "${event_digest_value}" ] || fail "cannot checkpoint an empty replay without an authenticated prior event"
  jq -cS . "${issue_file}" >"${workspace}/checkpoint-issue.canonical"
  issue_digest_value="$(sha256_file "${workspace}/checkpoint-issue.canonical")"
  local latest_issue
  latest_issue="$(jq -c 'sort_by(.number) | last // empty' "${issue_file}")"
  if [ -n "${latest_issue}" ]; then
    issue_number="$(jq -r .number <<<"${latest_issue}")"
    issue_state="$(jq -r .state <<<"${latest_issue}")"
  else
    issue_number=null
    issue_state=null
  fi
  previous="${checkpoint_chain}"
  jq -cnS \
    --arg repository "${GH_REPO}" --arg workflow_ref "${expected_workflow_ref}" \
    --arg event_digest "${event_digest_value}" --arg issue_digest "${issue_digest_value}" \
    --arg previous_chain_digest "${previous}" \
    --argjson run "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" \
    --argjson issue_number "${issue_number}" --arg issue_state "${issue_state}" \
    '{schema:"rindle-nightly-incident-checkpoint-v1",repository:$repository,workflow_ref:$workflow_ref,
      last_run_id:$run,last_run_attempt:$attempt,event_digest:$event_digest,
      previous_chain_digest:$previous_chain_digest,issue_number:$issue_number,
      issue_state:(if $issue_state == "null" then null else $issue_state end),
      issue_digest:$issue_digest,chain_digest:""}' >"${checkpoint_path}"
  jq -cS '{previous_chain_digest,last_run_id,last_run_attempt,event_digest,issue_digest,issue_number,issue_state}' \
    "${checkpoint_path}" >"${workspace}/checkpoint-chain-input.json"
  local chain
  chain="$(sha256_file "${workspace}/checkpoint-chain-input.json")"
  jq --arg chain "${chain}" '.chain_digest=$chain' "${checkpoint_path}" >"${workspace}/checkpoint-final.json"
  mv "${workspace}/checkpoint-final.json" "${checkpoint_path}"
}

# At genesis, a single labelled open incident with no mutation markers is
# adopted as the current incident. Fail closed when an open incident with the
# canonical title lacks the label, or when any mutation marker predates genesis.
check_genesis_preconditions() {
  [ "${checkpoint_run}" -eq 0 ] || return 0
  local titled issues="${workspace}/genesis-issues.json"
  titled="$(${GH_CLI:-gh} issue list --repo "${GH_REPO}" --state open \
    --search "in:title \"${incident_title}\"" --limit 100 --json number,title,labels)" ||
    fail "open incident title lookup failed"
  jq -e --arg title "${incident_title}" --arg wanted_label "${incident_label}" '
    type == "array" and
    ([.[] | select(.title == $title and ([.labels[]?.name] | index($wanted_label) | not))] | length == 0)
  ' >/dev/null <<<"${titled}" || fail "an open \"${incident_title}\" incident lacks the ${incident_label} label"
  inventory "${issues}"
  jq -e --argjson genesis "${genesis_run}" --argjson genesis_attempt "${genesis_attempt}" '
    [ .[] | .body, .comments[].body |
      scan("nightly-mutation:(?:open|update|close):([1-9][0-9]{0,19}):([1-9][0-9]{0,9})") |
      map(tonumber) | select(.[0] < $genesis or (.[0] == $genesis and .[1] < $genesis_attempt)) ] | length == 0
  ' "${issues}" >/dev/null || fail "incident mutation history predates the genesis run ${genesis_run}/${genesis_attempt}"
  echo "Nightly incident replay: genesis at ${genesis_run}/${genesis_attempt}; adopting $(jq -r '[.[] | select(.state == "OPEN") | "#\(.number)"] | if length == 0 then "no open incident" else .[0] end' "${issues}")"
}

mutation_body() {
  local intent_file="$1" body_file="$2"
  local action marker event
  action="$(jq -r .action "${intent_file}")"
  marker="$(jq -r .marker "${intent_file}")"
  event="$(jq -cS .event "${intent_file}")"
  {
    printf 'Nightly incident mutation: %s\n' "${action}"
    printf 'Evidence marker: %s\n' "${marker}"
    printf 'Authenticated verdict event: %s\n' "${event}"
  } >"${body_file}"
}

mutate() {
  local intent_file="$1" inventory_file="$2" body_file="$3"
  local action issue_number
  action="$(jq -r .action "${intent_file}")"
  issue_number="$(jq -r .issue_number "${intent_file}")"
  case "${action}" in
    open)
      [ "$(jq -r .open_count "${intent_file}")" -eq 0 ] || return 1
      ${GH_CLI:-gh} issue create --repo "${GH_REPO}" --title "${incident_title}" \
        --label "${incident_label}" --body-file "${body_file}" >/dev/null
      ;;
    update)
      [[ "${issue_number}" =~ ^[1-9][0-9]*$ ]] || return 1
      ${GH_CLI:-gh} issue comment "${issue_number}" --repo "${GH_REPO}" \
        --body-file "${body_file}" >/dev/null
      ;;
    close)
      [[ "${issue_number}" =~ ^[1-9][0-9]*$ ]] || return 1
      # gh issue close returns success without adding --comment to an already
      # closed issue. Record the authenticated recovery without reopening it.
      if [ "$(jq -r .issue_state "${intent_file}")" = CLOSED ]; then
        ${GH_CLI:-gh} issue comment "${issue_number}" --repo "${GH_REPO}" \
          --body-file "${body_file}" >/dev/null
      else
        ${GH_CLI:-gh} issue close "${issue_number}" --repo "${GH_REPO}" \
          --comment "$(<"${body_file}")" >/dev/null
      fi
      ;;
    *) fail "invalid mutation intent" ;;
  esac
}

# The issue list lags behind a mutation, so a restart that re-reads it too soon
# derives the same intent again (a second create opened #132 beside #131).
# Wait until the mutation's evidence marker is visible before restarting.
await_marker() {
  local marker="$1" seen="${workspace}/issues-visible.json" read
  for ((read = 1; read <= visibility_reads; read++)); do
    inventory "${seen}"
    if jq -e --arg marker "${marker}" \
      '[.[] | .body, .comments[].body] | any(contains($marker))' "${seen}" >/dev/null; then
      return 0
    fi
    sleep "${sleep_seconds}"
  done
  return 1
}

fetch_runs
for ((attempt = 1; attempt <= fetch_attempts; attempt++)); do
  fetch_artifacts
  load_checkpoint
  validate_checkpoint_issue
  if prepare_event_index; then break; fi
  if [ "${attempt}" -eq "${fetch_attempts}" ]; then
    fail "canonical verdict artifact coverage incomplete through high-watermark"
  fi
  sleep "${sleep_seconds}"
done
authenticate_events
check_genesis_preconditions

for ((restart = 1; restart <= max_restarts; restart++)); do
  before="${workspace}/issues-before-${restart}.json"
  fresh="${workspace}/issues-fresh-${restart}.json"
  intent="${workspace}/intent-${restart}.json"
  body="${workspace}/body-${restart}.txt"
  inventory "${before}"
  derive_intent "${before}" "${intent}"
  if [ "$(jq -r 'type' "${intent}")" = null ]; then
    write_checkpoint "${before}"
    echo "Nightly incident replay: converged through ${CURRENT_RUN_ID}/${CURRENT_RUN_ATTEMPT}"
    exit 0
  fi

  inventory "${fresh}"
  if [ "$(jq -cS . "${before}")" != "$(jq -cS . "${fresh}")" ]; then
    echo "Nightly incident replay: stale preimage, restarting" >&2
    continue
  fi
  mutation_body "${intent}" "${body}"
  marker="$(jq -r .marker "${intent}")"
  if ! mutate "${intent}" "${fresh}" "${body}"; then
    echo "Nightly incident replay: mutation outcome uncertain, restarting" >&2
    await_marker "${marker}" || true
    continue
  fi
  await_marker "${marker}" ||
    fail "mutation ${marker} not visible after ${visibility_reads} issue reads; refusing to re-derive"
done

fail "bounded replay exhausted before convergence"
