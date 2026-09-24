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

expected_workflow_ref="${GH_REPO}/.github/workflows/nightly.yml@refs/heads/${DEFAULT_BRANCH}"
[ "${WORKFLOW_REF}" = "${expected_workflow_ref}" ] || fail "unexpected WORKFLOW_REF"

workspace="$(mktemp -d)"
trap 'rm -rf "${workspace}"' EXIT
runs_file="${workspace}/runs.json"
artifacts_file="${workspace}/artifacts.json"
events_file="${workspace}/events.json"
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

prepare_event_index() {
  jq -e '
    all(.[];
      type == "object" and
      (.id | type == "number" and . > 0 and floor == .) and
      (.name | type == "string") and
      (.expired | type == "boolean") and
      (.workflow_run | type == "object") and
      (.workflow_run.id | type == "number" and . > 0 and floor == .)
    ) and
    ([.[].id] | length == (unique | length))
  ' "${artifacts_file}" >/dev/null || fail "invalid artifact metadata"

  jq -cS \
    --arg prefix 'nightly-incident-verdict-' \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" '
      [
        .[] |
        select(.expired == false) |
        select(.name | startswith($prefix)) |
        (.name | capture("^nightly-incident-verdict-(?<run>[1-9][0-9]{0,19})-(?<attempt>[1-9][0-9]{0,9})$")) as $identity |
        {
          artifact_id:.id,
          name:.name,
          workflow_run_id:.workflow_run.id,
          run_id:($identity.run | tonumber),
          run_attempt:($identity.attempt | tonumber)
        } |
        select(.run_id < $high or (.run_id == $high and .run_attempt <= $high_attempt))
      ]
    ' "${artifacts_file}" >"${workspace}/event-index.json" || fail "malformed canonical artifact name"

  jq -e '
    all(.[]; .workflow_run_id == .run_id) and
    (group_by([.run_id, .run_attempt]) | all(.[]; length == 1))
  ' "${workspace}/event-index.json" >/dev/null || fail "duplicate or mismatched canonical event artifact"

  jq -cS \
    --arg branch "${DEFAULT_BRANCH}" \
    --argjson high "${CURRENT_RUN_ID}" --argjson high_attempt "${CURRENT_RUN_ATTEMPT}" '
      [
        .[] |
        select((.id < $high or (.id == $high and .run_attempt <= $high_attempt)) and .head_branch == $branch) |
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

  jq -e --argjson high "${CURRENT_RUN_ID}" --argjson attempt "${CURRENT_RUN_ATTEMPT}" '
    sort_by(.run_id, .run_attempt) | last | .run_id == $high and .run_attempt == $attempt
  ' "${workspace}/event-index.json" >/dev/null || fail "artifact high-watermark does not match current run"
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
  local first_run first_attempt
  jq -r '[.[] | .body, .comments[].body] | .[] | scan("nightly-mutation:(?:open|update|close):[1-9][0-9]{0,19}:[1-9][0-9]{0,9}")' \
    "${inventory_file}" | sort >"${marker_file}"
  open_count="$(jq '[.[] | select(.state == "OPEN")] | length' "${inventory_file}")"
  logical_open=false
  first_run="$(jq -r '.[0].run_id' "${events_file}")"
  first_attempt="$(jq -r '.[0].run_attempt' "${events_file}")"
  if { [ ! -s "${marker_file}" ] && [ "${open_count}" -eq 1 ]; } ||
     grep -Eq "^nightly-mutation:(update|close):${first_run}:${first_attempt}$" "${marker_file}"; then
    logical_open=true
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
    else
      [ "${same_event_count}" -eq 0 ] || fail "event owns the wrong mutation marker"
      if [ "${missing}" = false ]; then
        jq -cn --arg action "${action}" --arg marker "${marker}" --argjson event "${event}" \
          --argjson open "${open_count}" '{action:$action,marker:$marker,event:$event,open_count:$open}' >"${intent_file}"
        missing=true
      fi
    fi
    case "${action}" in open|update) logical_open=true ;; close) logical_open=false ;; esac
  done < <(jq -c '.[]' "${events_file}")

  if [ "${missing}" = false ]; then
    if { [ "${logical_open}" = true ] && [ "${open_count}" -ne 1 ]; } ||
       { [ "${logical_open}" = false ] && [ "${open_count}" -ne 0 ]; }; then
      fail "incident state disagrees with authenticated mutation history"
    fi
  fi
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
  issue_number="$(jq -r '[.[] | select(.state == "OPEN")][0].number // empty' "${inventory_file}")"
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
      ${GH_CLI:-gh} issue close "${issue_number}" --repo "${GH_REPO}" \
        --comment "$(<"${body_file}")" >/dev/null
      ;;
    *) fail "invalid mutation intent" ;;
  esac
}

fetch_runs
for ((attempt = 1; attempt <= fetch_attempts; attempt++)); do
  fetch_artifacts
  if prepare_event_index; then break; fi
  if [ "${attempt}" -eq "${fetch_attempts}" ]; then
    fail "canonical verdict artifact coverage incomplete through high-watermark"
  fi
  sleep "${sleep_seconds}"
done
authenticate_events

for ((restart = 1; restart <= max_restarts; restart++)); do
  before="${workspace}/issues-before-${restart}.json"
  fresh="${workspace}/issues-fresh-${restart}.json"
  intent="${workspace}/intent-${restart}.json"
  body="${workspace}/body-${restart}.txt"
  inventory "${before}"
  derive_intent "${before}" "${intent}"
  if [ "$(jq -r 'type' "${intent}")" = null ]; then
    echo "Nightly incident replay: converged through ${CURRENT_RUN_ID}/${CURRENT_RUN_ATTEMPT}"
    exit 0
  fi

  inventory "${fresh}"
  if [ "$(jq -cS . "${before}")" != "$(jq -cS . "${fresh}")" ]; then
    echo "Nightly incident replay: stale preimage, restarting" >&2
    continue
  fi
  mutation_body "${intent}" "${body}"
  if ! mutate "${intent}" "${fresh}" "${body}"; then
    echo "Nightly incident replay: mutation outcome uncertain, restarting" >&2
    continue
  fi
done

fail "bounded replay exhausted before convergence"
