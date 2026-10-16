#!/usr/bin/env bash
# Stateful regression matrix for immutable Nightly verdict replay.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manager="${here}/manage_nightly_incident.sh"
sha_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
sha_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
sha_foreign=cccccccccccccccccccccccccccccccccccccccc

pass=0
fail=0

record() {
  local name="$1" ok="$2" detail="$3"
  if [ "${ok}" = true ]; then
    echo "ok   — ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: ${detail}" >&2
    fail=$((fail + 1))
  fi
}

write_event() {
  local path="$1" run_id="$2" attempt="$3" verdict="$4" sha="${5:-${sha_a}}"
  jq -cS -n \
    --arg schema rindle-nightly-incident-verdict-v1 \
    --arg repository szTheory/rindle \
    --arg workflow_name Nightly \
    --arg workflow_ref szTheory/rindle/.github/workflows/nightly.yml@refs/heads/main \
    --arg event schedule \
    --argjson run_id "${run_id}" \
    --argjson run_attempt "${attempt}" \
    --arg sha "${sha}" \
    --arg ref refs/heads/main \
    --arg url "https://github.com/szTheory/rindle/actions/runs/${run_id}" \
    --arg verdict "${verdict}" \
    '{schema:$schema,repository:$repository,workflow_name:$workflow_name,workflow_ref:$workflow_ref,event:$event,run_id:$run_id,run_attempt:$run_attempt,sha:$sha,ref:$ref,url:$url,verdict:{verdict:$verdict,jobs:[{name:"dialyzer",status:(if $verdict == "green" then "passed" else "failed" end)}],errors:(if $verdict == "green" then [] else ["dialyzer failed"] end)}}' \
    >"${path}"
}

write_runs() {
  local path="$1"
  jq -cn '{workflow_runs:[
    {id:101,run_attempt:1,event:"schedule",status:"completed",conclusion:"failure",head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",head_branch:"main",html_url:"https://github.com/szTheory/rindle/actions/runs/101",name:"Nightly",path:".github/workflows/nightly.yml"},
    {id:102,run_attempt:1,event:"schedule",status:"completed",conclusion:"failure",head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",head_branch:"main",html_url:"https://github.com/szTheory/rindle/actions/runs/102",name:"Nightly",path:".github/workflows/nightly.yml"},
    {id:103,run_attempt:1,event:"schedule",status:"in_progress",conclusion:null,head_sha:"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",head_branch:"main",html_url:"https://github.com/szTheory/rindle/actions/runs/103",name:"Nightly",path:".github/workflows/nightly.yml"}
  ]}' >"${path}"
}

write_artifacts() {
  local path="$1" mode="${2:-all}" created expires
  case "${mode}" in
    all)
      jq -cn '{artifacts:[
        {id:1001,name:"nightly-incident-verdict-101-1",expired:false,workflow_run:{id:101}},
        {id:1002,name:"nightly-incident-verdict-102-1",expired:false,workflow_run:{id:102}},
        {id:1003,name:"nightly-incident-verdict-103-1",expired:false,workflow_run:{id:103}}
      ]}' >"${path}"
      ;;
    missing-middle)
      jq -cn '{artifacts:[
        {id:1001,name:"nightly-incident-verdict-101-1",expired:false,workflow_run:{id:101}},
        {id:1003,name:"nightly-incident-verdict-103-1",expired:false,workflow_run:{id:103}}
      ]}' >"${path}"
      ;;
    duplicate-middle)
      jq -cn '{artifacts:[
        {id:1001,name:"nightly-incident-verdict-101-1",expired:false,workflow_run:{id:101}},
        {id:1002,name:"nightly-incident-verdict-102-1",expired:false,workflow_run:{id:102}},
        {id:2002,name:"nightly-incident-verdict-102-1",expired:false,workflow_run:{id:102}},
        {id:1003,name:"nightly-incident-verdict-103-1",expired:false,workflow_run:{id:103}}
      ]}' >"${path}"
      ;;
    green-only)
      jq -cn '{artifacts:[{id:1003,name:"nightly-incident-verdict-103-1",expired:false,workflow_run:{id:103}}]}' >"${path}"
      ;;
  esac
  read -r _ created expires <<<"$(python3 -c 'from datetime import datetime, timedelta, timezone; now=datetime.now(timezone.utc); print(int(now.timestamp()), now.isoformat(timespec="seconds").replace("+00:00","Z"), (now+timedelta(days=14)).isoformat(timespec="seconds").replace("+00:00","Z"))')"
  jq --arg created "${created}" --arg expires "${expires}" \
    '.artifacts |= map(. + {created_at:$created,expires_at:$expires})' "${path}" >"${path}.next"
  mv "${path}.next" "${path}"
}

make_fake_gh() {
  local bin_dir="$1"
  mkdir -p "${bin_dir}"
  # shellcheck disable=SC2016 # Literals become the fake executable's source.
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "%s\n" "$*" >> "${FAKE_GH_LOG}"' \
    'state="${FAKE_STATE}"' \
    'counter() { local name="$1" path value=0; path="${state}/${name}"; [ ! -f "${path}" ] || value="$(<"${path}")"; value=$((value + 1)); printf "%s\n" "${value}" >"${path}"; printf "%s" "${value}"; }' \
    'if [ "${1-}" = api ]; then' \
    '  [ "${FAKE_GH_FAIL-}" != api ] || exit 41' \
    '  case "$*" in' \
    '    *"actions/runs/"*"/attempts/"*)' \
    '      run_id="$(sed -E "s#.*actions/runs/([0-9]+)/attempts/([0-9]+).*#\\1#" <<<"$*")"' \
    '      attempt="$(sed -E "s#.*actions/runs/([0-9]+)/attempts/([0-9]+).*#\\2#" <<<"$*")"' \
    '      jq -ce --argjson id "$run_id" --argjson attempt "$attempt" '\''[.workflow_runs[] | select(.id == $id) | . + {run_attempt:$attempt}] | .[0] // error("missing run")'\'' "${state}/runs.json"' \
    '      ;;' \
    '    *"actions/workflows/nightly.yml/runs"*) jq -cn --slurpfile page "${state}/runs.json" '\''[$page[0]]'\'' ;;' \
    '    *"actions/artifacts"*)' \
    '      n="$(counter artifact_reads)"' \
    '      source="${state}/artifacts.json"' \
    '      [ ! -f "${state}/artifacts-${n}.json" ] || source="${state}/artifacts-${n}.json"' \
    '      jq -cn --slurpfile page "${source}" '\''[$page[0]]'\'' ' \
    '      ;;' \
    '    *) exit 43 ;;' \
    '  esac' \
    '  exit 0' \
    'fi' \
    'if [ "${1-} ${2-}" = "run download" ]; then' \
    '  name=""; dir=""; shift 3' \
    '  while [ "$#" -gt 0 ]; do case "$1" in --name) name="$2"; shift 2 ;; --dir) dir="$2"; shift 2 ;; *) shift ;; esac; done' \
    '  [ "${FAKE_GH_FAIL-}" != download ] || exit 44' \
    '  mkdir -p "${dir}"' \
    '  case "${name}" in' \
    '    nightly-incident-replay-checkpoint-*) cp "${state}/checkpoint.json" "${dir}/nightly-incident-checkpoint.json" ;;' \
    '    *) cp "${state}/events/${name}.json" "${dir}/nightly-incident-verdict.json" ;;' \
    '  esac' \
    '  exit 0' \
    'fi' \
    'if [ "${1-} ${2-}" = "issue list" ] && [[ "$*" == *--search* ]]; then' \
    '  if [ -f "${state}/title-search.json" ]; then cat "${state}/title-search.json"; else printf "[]\\n"; fi' \
    '  exit 0' \
    'fi' \
    'if [ "${1-} ${2-}" = "issue list" ]; then' \
    '  [ "${FAKE_GH_FAIL-}" != list ] || exit 45' \
    '  n="$(counter issue_reads)"' \
    '  lag=0; [ ! -f "${state}/lag_remaining" ] || lag="$(<"${state}/lag_remaining")"' \
    '  if [ "${lag}" -gt 0 ]; then printf "%s\n" "$((lag - 1))" >"${state}/lag_remaining"; cat "${state}/issues.lagged"; exit 0; fi' \
    '  if [ "${FAKE_STALE_ONCE-}" = true ] && [ "${n}" -eq 2 ]; then' \
    '    jq '\''if length == 0 then [{number:77,title:"Nightly CI failure",state:"OPEN",body:"external drift",comments:[]}] else .[0].comments += [{body:"external drift"}] end'\'' "${state}/issues.json" >"${state}/issues.next"' \
    '    mv "${state}/issues.next" "${state}/issues.json"' \
    '  fi' \
    '  cat "${state}/issues.json"' \
    '  exit 0' \
    'fi' \
    'body_from_args() { local body_file="" body=""; while [ "$#" -gt 0 ]; do case "$1" in --body-file) body_file="$2"; shift 2 ;; --comment) body="$2"; shift 2 ;; *) shift ;; esac; done; if [ -n "${body_file}" ]; then cat "${body_file}"; else printf "%s" "${body}"; fi; }' \
    'mutation="${2-}"' \
    'if [ "${1-}" = issue ] && [ "${mutation}" != list ]; then' \
    '  n="$(counter mutation_attempts)"' \
    '  if [ "${FAKE_GH_FAIL-}" = mutation ]; then exit 46; fi' \
    '  uncertain=false; [ "${FAKE_GH_UNCERTAIN_ONCE-}" != true ] || [ "${n}" -ne 1 ] || uncertain=true' \
    '  body="$(body_from_args "$@")"' \
    '  case "${mutation}" in' \
    '    create)' \
    '      jq --arg body "${body}" '\''. + [{number:88,title:"Nightly CI failure",state:"OPEN",body:$body,comments:[]}]'\'' "${state}/issues.json" >"${state}/issues.next"' \
    '      ;;' \
    '    comment)' \
    '      number="${3}"' \
    '      jq --argjson number "${number}" --arg body "${body}" '\''map(if .number == $number then .comments += [{body:$body}] else . end)'\'' "${state}/issues.json" >"${state}/issues.next"' \
    '      ;;' \
    '    close)' \
    '      number="${3}"' \
    '      jq --argjson number "${number}" --arg body "${body}" '\''map(if .number == $number then .state = "CLOSED" | .comments += [{body:$body}] else . end)'\'' "${state}/issues.json" >"${state}/issues.next"' \
    '      ;;' \
    '    *) exit 47 ;;' \
    '  esac' \
    '  if [ -n "${FAKE_LIST_LAG-}" ]; then cp "${state}/issues.json" "${state}/issues.lagged"; printf "%s\n" "${FAKE_LIST_LAG}" >"${state}/lag_remaining"; fi' \
    '  [ "${mutation}" != create ] || counter creates >/dev/null' \
    '  mv "${state}/issues.next" "${state}/issues.json"' \
    '  [ "${uncertain}" = false ] || exit 48' \
    '  exit 0' \
    'fi' \
    'exit 49' >"${bin_dir}/gh"
  chmod +x "${bin_dir}/gh"
  # shellcheck disable=SC2016 # Source text is emitted verbatim into the fake date command.
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'if [ "$*" = "-u +%s" ] && [ -n "${FAKE_NOW_EPOCH-}" ]; then printf "%s\\n" "${FAKE_NOW_EPOCH}"; else /bin/date "$@"; fi' \
    >"${bin_dir}/date"
  chmod +x "${bin_dir}/date"
}

new_fixture() {
  local temp
  temp="$(mktemp -d)"
  mkdir -p "${temp}/state/events" "${temp}/bin"
  make_fake_gh "${temp}/bin"
  : >"${temp}/calls"
  printf '[]\n' >"${temp}/state/issues.json"
  write_runs "${temp}/state/runs.json"
  write_artifacts "${temp}/state/artifacts.json"
  write_event "${temp}/state/events/nightly-incident-verdict-101-1.json" 101 1 red
  write_event "${temp}/state/events/nightly-incident-verdict-102-1.json" 102 1 red
  write_event "${temp}/state/events/nightly-incident-verdict-103-1.json" 103 1 green "${sha_b}"
  printf '%s' "${temp}"
}

run_manager() {
  local temp="$1" output="$2"
  shift 2
  env PATH="${temp}/bin:${PATH}" FAKE_STATE="${temp}/state" FAKE_GH_LOG="${temp}/calls" \
    GH_TOKEN=test-token GH_REPO=szTheory/rindle WORKFLOW_NAME=Nightly \
    WORKFLOW_REF=szTheory/rindle/.github/workflows/nightly.yml@refs/heads/main \
    CURRENT_RUN_ID=103 CURRENT_RUN_ATTEMPT=1 DEFAULT_BRANCH=main \
    REMOTE_MAIN_SHA="${sha_b}" CHECKPOINT_OUTPUT_PATH="${temp}/state/checkpoint-output.json" \
    NIGHTLY_REPLAY_SLEEP_SECONDS=0 NIGHTLY_REPLAY_FETCH_ATTEMPTS=3 NIGHTLY_REPLAY_MAX_RESTARTS=20 \
    "$@" bash "${manager}" >"${output}" 2>&1
}

install_checkpoint() {
  local temp="$1" run_id="$2" attempt="$3" issue_digest event_digest previous chain
  local issue_number=null issue_state=null
  if [ "$(jq length "${temp}/state/issues.json")" -gt 0 ]; then
    issue_number="$(jq -r 'sort_by(.number) | last | .number' "${temp}/state/issues.json")"
    issue_state="$(jq -r --argjson number "${issue_number}" '.[] | select(.number == $number) | .state' "${temp}/state/issues.json")"
  fi
  jq -cS . "${temp}/state/events/nightly-incident-verdict-${run_id}-${attempt}.json" >"${temp}/event-canonical.json"
  event_digest="$(sha256sum "${temp}/event-canonical.json" | awk '{print $1}')"
  jq -cS . "${temp}/state/issues.json" >"${temp}/issues-canonical.json"
  issue_digest="$(sha256sum "${temp}/issues-canonical.json" | awk '{print $1}')"
  previous="$(printf '0%.0s' {1..64})"
  jq -cnS --arg repository szTheory/rindle \
    --arg workflow_ref szTheory/rindle/.github/workflows/nightly.yml@refs/heads/main \
    --arg event_digest "${event_digest}" --arg issue_digest "${issue_digest}" \
    --arg previous_chain_digest "${previous}" --argjson run "${run_id}" \
    --argjson attempt "${attempt}" --argjson issue_number "${issue_number}" \
    --arg issue_state "${issue_state}" \
    '{schema:"rindle-nightly-incident-checkpoint-v1",repository:$repository,workflow_ref:$workflow_ref,
      last_run_id:$run,last_run_attempt:$attempt,event_digest:$event_digest,
      previous_chain_digest:$previous_chain_digest,issue_number:$issue_number,
      issue_state:(if $issue_state == "null" then null else $issue_state end),
      issue_digest:$issue_digest,chain_digest:""}' >"${temp}/state/checkpoint.json"
  jq -cS '{previous_chain_digest,last_run_id,last_run_attempt,event_digest,issue_digest,issue_number,issue_state}' \
    "${temp}/state/checkpoint.json" >"${temp}/chain-input.json"
  chain="$(sha256sum "${temp}/chain-input.json" | awk '{print $1}')"
  jq --arg chain "${chain}" '.chain_digest=$chain' "${temp}/state/checkpoint.json" >"${temp}/checkpoint.next"
  mv "${temp}/checkpoint.next" "${temp}/state/checkpoint.json"
  jq --argjson run "${run_id}" --argjson attempt "${attempt}" \
    --arg created "$(jq -r '.artifacts[0].created_at' "${temp}/state/artifacts.json")" \
    --arg expires "$(jq -r '.artifacts[0].expires_at' "${temp}/state/artifacts.json")" \
    '.artifacts += [{id:(3000+$run),name:("nightly-incident-replay-checkpoint-"+($run|tostring)+"-"+($attempt|tostring)),expired:false,workflow_run:{id:$run},created_at:$created,expires_at:$expires}]' \
    "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
  mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
}

seed_checkpoint_issue() {
  local temp="$1" run_id="$2"
  if [ "${run_id}" -eq 102 ]; then
    jq -cn '[{number:88,title:"Nightly CI failure",state:"OPEN",
      body:"Nightly incident mutation: open\nEvidence marker: nightly-mutation:open:101:1",
      comments:[{body:"Nightly incident mutation: update\nEvidence marker: nightly-mutation:update:102:1"}]}]' \
      >"${temp}/state/issues.json"
  else
    jq -cn '[{number:88,title:"Nightly CI failure",state:"OPEN",
      body:"Nightly incident mutation: open\nEvidence marker: nightly-mutation:open:101:1",comments:[]}]' \
      >"${temp}/state/issues.json"
  fi
  install_checkpoint "${temp}" "${run_id}" 1
}

mutation_effects() {
  local temp="$1"
  jq '[.[] | .body, .comments[].body] | map(select(type == "string")) | map(scan("nightly-mutation:[a-z]+:[0-9]+:[0-9]+")) | flatten | length' \
    "${temp}/state/issues.json"
}

three_overlap_case() {
  local temp output got=0 b_count state effects
  temp="$(new_fixture)"
  output="${temp}/output"
  run_manager "${temp}" "${output}" || got=$?
  b_count="$({ grep -o 'nightly-mutation:update:102:1' "${temp}/state/issues.json" || true; } | wc -l | tr -d ' ')"
  state="$(jq -r '.[0].state // "missing"' "${temp}/state/issues.json")"
  effects="$(mutation_effects "${temp}")"
  if [ "${got}" -eq 0 ] && [ "${b_count}" -eq 1 ] && [ "${state}" = CLOSED ] && [ "${effects}" -eq 3 ]; then
    record "red-A/green-B history opens, updates, and closes exactly once" true ""
  else
    record "red-A/green-B history opens, updates, and closes exactly once" false "exit=${got} B=${b_count} state=${state} effects=${effects}; $(<"${output}")"
  fi

  : >"${temp}/calls"
  rm -f "${temp}/state/artifact_reads" "${temp}/state/issue_reads" "${temp}/state/mutation_attempts"
  got=0
  run_manager "${temp}" "${output}" || got=$?
  local replay_attempts=0
  [ ! -f "${temp}/state/mutation_attempts" ] || replay_attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -eq 0 ] && [ "${replay_attempts}" -eq 0 ] && [ "$(mutation_effects "${temp}")" -eq 3 ]; then
    record "same complete log replay is mutation-idempotent" true ""
  else
    record "same complete log replay is mutation-idempotent" false "replay exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

green_no_incident_case() {
  local temp output got=0
  temp="$(new_fixture)"
  output="${temp}/output"
  jq '.workflow_runs = [.workflow_runs[-1]]' "${temp}/state/runs.json" >"${temp}/state/runs.next"
  mv "${temp}/state/runs.next" "${temp}/state/runs.json"
  write_artifacts "${temp}/state/artifacts.json" green-only
  run_manager "${temp}" "${output}" || got=$?
  run_manager "${temp}" "${output}" || got=$?
  if [ "${got}" -eq 0 ] && [ "$(jq length "${temp}/state/issues.json")" -eq 0 ] && ! grep -q 'nightly-mutation:' "${temp}/state/issues.json"; then
    record "repeated green with no incident is an unmarked no-op" true ""
  else
    record "repeated green with no incident is an unmarked no-op" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

delayed_artifact_case() {
  local temp output got=0
  temp="$(new_fixture)"
  output="${temp}/output"
  write_artifacts "${temp}/state/artifacts-1.json" missing-middle
  run_manager "${temp}" "${output}" || got=$?
  if [ "${got}" -eq 0 ] && [ "$(mutation_effects "${temp}")" -eq 3 ] && [ "$(<"${temp}/state/artifact_reads")" -ge 2 ]; then
    record "delayed middle artifact is retried before mutation" true ""
  else
    record "delayed middle artifact is retried before mutation" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

fail_closed_case() {
  local name="$1" setup="$2" extra_env="${3:-}" temp output got=0 attempts
  temp="$(new_fixture)"
  output="${temp}/output"
  case "${setup}" in
    missing) write_artifacts "${temp}/state/artifacts.json" missing-middle ;;
    duplicate) write_artifacts "${temp}/state/artifacts.json" duplicate-middle ;;
    malformed) printf '{not-json\n' >"${temp}/state/events/nightly-incident-verdict-102-1.json" ;;
    foreign) jq '.repository = "mallory/fork"' "${temp}/state/events/nightly-incident-verdict-102-1.json" >"${temp}/state/event.next" && mv "${temp}/state/event.next" "${temp}/state/events/nightly-incident-verdict-102-1.json" ;;
    mismatch) jq '.run_id = 999' "${temp}/state/events/nightly-incident-verdict-102-1.json" >"${temp}/state/event.next" && mv "${temp}/state/event.next" "${temp}/state/events/nightly-incident-verdict-102-1.json" ;;
    sha-mismatch) jq --arg sha "${sha_b}" '.sha = $sha' "${temp}/state/events/nightly-incident-verdict-102-1.json" >"${temp}/state/event.next" && mv "${temp}/state/event.next" "${temp}/state/events/nightly-incident-verdict-102-1.json" ;;
    collision)
      jq -cn '[
        {number:88,title:"Nightly CI failure",state:"CLOSED",body:"nightly-mutation:open:101:1",comments:[]},
        {number:89,title:"Nightly CI failure",state:"CLOSED",body:"nightly-mutation:open:101:1",comments:[]}
      ]' >"${temp}/state/issues.json"
      ;;
    simultaneous)
      jq -cn '[
        {number:88,title:"Nightly CI failure",state:"OPEN",body:"",comments:[]},
        {number:89,title:"Nightly CI failure",state:"OPEN",body:"",comments:[]}
      ]' >"${temp}/state/issues.json"
      ;;
  esac
  if [ -n "${extra_env}" ]; then
    run_manager "${temp}" "${output}" "${extra_env}" || got=$?
  else
    run_manager "${temp}" "${output}" || got=$?
  fi
  attempts=0
  [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -ne 0 ] && [ "${attempts}" -eq 0 ]; then
    record "${name}" true ""
  else
    record "${name}" false "expected pre-mutation failure, got exit=${got} attempts=${attempts}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

restart_case() {
  local name="$1" mode="$2" temp output got=0
  temp="$(new_fixture)"
  output="${temp}/output"
  if [ "${mode}" = stale ]; then
    run_manager "${temp}" "${output}" FAKE_STALE_ONCE=true || got=$?
  else
    run_manager "${temp}" "${output}" FAKE_GH_UNCERTAIN_ONCE=true || got=$?
  fi
  if [ "${got}" -eq 0 ] && [ "$(mutation_effects "${temp}")" -eq 3 ] && [ "$(jq '[.[] | select(.state == "OPEN")] | length' "${temp}/state/issues.json")" -eq 0 ]; then
    record "${name}" true ""
  else
    record "${name}" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

lagged_list_case() {
  local name="$1" lag="$2" reads="$3" want="$4" temp output got=0 creates
  temp="$(new_fixture)"
  output="${temp}/output"
  run_manager "${temp}" "${output}" FAKE_LIST_LAG="${lag}" NIGHTLY_REPLAY_VISIBILITY_READS="${reads}" || got=$?
  creates=0
  [ ! -f "${temp}/state/creates" ] || creates="$(<"${temp}/state/creates")"
  if [ "${want}" = converge ] && [ "${got}" -eq 0 ] && [ "${creates}" -eq 1 ] &&
    [ "$(mutation_effects "${temp}")" -eq 3 ] &&
    [ "$(jq '[.[] | select(.state == "OPEN")] | length' "${temp}/state/issues.json")" -eq 0 ]; then
    record "${name}" true ""
  elif [ "${want}" = fail ] && [ "${got}" -ne 0 ] && [ "${creates}" -eq 1 ] &&
    grep -q 'not visible after' "${output}"; then
    record "${name}" true ""
  else
    record "${name}" false "exit=${got} creates=${creates}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

permanent_mutation_failure_case() {
  local temp output got=0 attempts
  temp="$(new_fixture)"
  output="${temp}/output"
  run_manager "${temp}" "${output}" FAKE_GH_FAIL=mutation NIGHTLY_REPLAY_MAX_RESTARTS=3 || got=$?
  attempts=0
  [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -ne 0 ] && [ "${attempts}" -eq 3 ] && [ "$(jq length "${temp}/state/issues.json")" -eq 0 ]; then
    record "bounded uncertain mutation exhaustion fails without skipping" true ""
  else
    record "bounded uncertain mutation exhaustion fails without skipping" false "exit=${got} attempts=${attempts}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

two_attempts_case() {
  local temp output got=0
  temp="$(new_fixture)"
  output="${temp}/output"
  jq '(.workflow_runs[] | select(.id == 103) | .run_attempt) = 2' "${temp}/state/runs.json" >"${temp}/state/runs.next"
  mv "${temp}/state/runs.next" "${temp}/state/runs.json"
    jq --arg created "$(jq -r '.artifacts[0].created_at' "${temp}/state/artifacts.json")" \
      --arg expires "$(jq -r '.artifacts[0].expires_at' "${temp}/state/artifacts.json")" \
      '.artifacts += [{id:1004,name:"nightly-incident-verdict-103-2",expired:false,workflow_run:{id:103},created_at:$created,expires_at:$expires}]' \
    "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
  mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
  write_event "${temp}/state/events/nightly-incident-verdict-103-1.json" 103 1 red "${sha_b}"
  write_event "${temp}/state/events/nightly-incident-verdict-103-2.json" 103 2 green "${sha_b}"
  run_manager "${temp}" "${output}" CURRENT_RUN_ATTEMPT=2 || got=$?
  if [ "${got}" -eq 0 ] && [ "$(mutation_effects "${temp}")" -eq 4 ] && \
     grep -q 'nightly-mutation:update:103:1' "${temp}/state/issues.json" && \
     grep -q 'nightly-mutation:close:103:2' "${temp}/state/issues.json"; then
    record "both scheduled attempts replay as distinct ordered events" true ""
  else
    record "both scheduled attempts replay as distinct ordered events" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

checkpoint_case() {
  local name="$1" setup="$2" temp output got=0 effects
  temp="$(new_fixture)"
  output="${temp}/output"
  case "${setup}" in
    expired-pre-epoch)
      seed_checkpoint_issue "${temp}" 102
      jq '.artifacts |= map(if .name == "nightly-incident-verdict-101-1" then .expired=true else . end)' \
        "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
      mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
      ;;
    expired-in-epoch)
      seed_checkpoint_issue "${temp}" 101
      jq '.artifacts |= map(if .name == "nightly-incident-verdict-102-1" then .expired=true else . end)' \
        "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
      mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
      ;;
    tampered)
      seed_checkpoint_issue "${temp}" 102
      jq '.event_digest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
        "${temp}/state/checkpoint.json" >"${temp}/state/checkpoint.next"
      mv "${temp}/state/checkpoint.next" "${temp}/state/checkpoint.json"
      ;;
    concurrent-advance)
      seed_checkpoint_issue "${temp}" 102
      jq '.[0].comments += [{body:"concurrent history advancement"}]' \
        "${temp}/state/issues.json" >"${temp}/state/issues.next"
      mv "${temp}/state/issues.next" "${temp}/state/issues.json"
      ;;
    short-retention)
      read -r _ created expires <<<"$(python3 -c 'from datetime import datetime, timedelta, timezone; now=datetime.now(timezone.utc); print(int(now.timestamp()), now.isoformat(timespec="seconds").replace("+00:00","Z"), (now+timedelta(days=7)).isoformat(timespec="seconds").replace("+00:00","Z"))')"
      jq --arg created "${created}" --arg expires "${expires}" \
        '.artifacts |= map(if (.name | startswith("nightly-incident-verdict-")) then .created_at=$created | .expires_at=$expires else . end)' \
        "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
      mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
      ;;
  esac
  case "${setup}" in
    expired-pre-epoch)
      run_manager "${temp}" "${output}" || got=$?
      effects="$(mutation_effects "${temp}")"
      if [ "${got}" -eq 0 ] && [ "${effects}" -eq 3 ] && grep -q 'nightly-mutation:close:103:1' "${temp}/state/issues.json"; then
        record "${name}" true ""
      else
        record "${name}" false "exit=${got} effects=${effects}; $(<"${output}")"
      fi
      ;;
    *)
      run_manager "${temp}" "${output}" || got=$?
      local attempts=0
      [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
      if [ "${got}" -ne 0 ] && [ "${attempts}" -eq 0 ]; then
        record "${name}" true ""
      else
        record "${name}" false "exit=${got} mutations=${attempts}; $(<"${output}")"
      fi
      ;;
  esac
  rm -rf "${temp}"
}

checkpoint_expiry_boundary_case() {
  local delta="$1" temp output got=0 now created expires
  temp="$(new_fixture)"
  output="${temp}/output"
  seed_checkpoint_issue "${temp}" 102
  read -r now created expires <<<"$(python3 -c 'from datetime import datetime, timedelta, timezone; import sys; now=datetime.now(timezone.utc); print(int(now.timestamp()), (now-timedelta(days=14)).isoformat(timespec="seconds").replace("+00:00","Z"), (now+timedelta(seconds=int(sys.argv[1]))).isoformat(timespec="seconds").replace("+00:00","Z"))' "${delta}")"
  jq --arg created "${created}" --arg expires "${expires}" \
    '.artifacts |= map(if .name == "nightly-incident-replay-checkpoint-102-1" or .name == "nightly-incident-verdict-102-1" then .created_at=$created | .expires_at=$expires else . end)' \
    "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
  mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
  run_manager "${temp}" "${output}" "FAKE_NOW_EPOCH=${now}" || got=$?
  if [ "${delta}" -lt 3600 ]; then
    local attempts=0
    [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
    if [ "${got}" -ne 0 ] && [ "${attempts}" -eq 0 ]; then
      record "checkpoint inside expiry safety margin fails before mutation" true ""
    else
      record "checkpoint inside expiry safety margin fails before mutation" false "exit=${got} mutations=${attempts}; $(<"${output}")"
    fi
  elif [ "${got}" -eq 0 ] && jq -e '.last_run_id == 103 and .last_run_attempt == 1' "${temp}/state/checkpoint-output.json" >/dev/null; then
    record "near-expiry checkpoint advances through active high-watermark" true ""
  else
    record "near-expiry checkpoint advances through active high-watermark" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

skipped_attempt_case() {
  local temp output got=0
  temp="$(new_fixture)"
  output="${temp}/output"
  jq '(.workflow_runs[] | select(.id == 103) | .run_attempt) = 2' "${temp}/state/runs.json" >"${temp}/state/runs.next"
  mv "${temp}/state/runs.next" "${temp}/state/runs.json"
  jq --arg created "$(jq -r '.artifacts[0].created_at' "${temp}/state/artifacts.json")" \
    --arg expires "$(jq -r '.artifacts[0].expires_at' "${temp}/state/artifacts.json")" \
    '.artifacts = (.artifacts + [{id:1004,name:"nightly-incident-verdict-103-2",expired:false,workflow_run:{id:103},created_at:$created,expires_at:$expires}] | map(select(.name != "nightly-incident-verdict-103-1")))' \
    "${temp}/state/artifacts.json" >"${temp}/state/artifacts.next"
  mv "${temp}/state/artifacts.next" "${temp}/state/artifacts.json"
  write_event "${temp}/state/events/nightly-incident-verdict-103-2.json" 103 2 green "${sha_b}"
  run_manager "${temp}" "${output}" CURRENT_RUN_ATTEMPT=2 || got=$?
  if [ "${got}" -ne 0 ] && [ "$(jq length "${temp}/state/issues.json")" -eq 0 ]; then
    record "a missing earlier attempt fails before incident mutation" true ""
  else
    record "a missing earlier attempt fails before incident mutation" false "exit=${got}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

three_overlap_case
green_no_incident_case
delayed_artifact_case
fail_closed_case "missing middle artifact fails before issue mutation" missing
fail_closed_case "duplicate event artifact fails before issue mutation" duplicate
fail_closed_case "malformed event fails before issue mutation" malformed
fail_closed_case "foreign repository event fails before issue mutation" foreign
fail_closed_case "run/artifact identity mismatch fails before issue mutation" mismatch
fail_closed_case "historical event SHA mismatch fails before issue mutation" sha-mismatch
fail_closed_case "foreign high-watermark SHA fails before issue mutation" none "REMOTE_MAIN_SHA=${sha_foreign}"
fail_closed_case "duplicate marker ownership fails closed" collision
fail_closed_case "simultaneous open incidents fail closed" simultaneous
fail_closed_case "workflow-run API failure performs no issue mutation" none FAKE_GH_FAIL=api
restart_case "stale mutation preimage restarts full replay" stale
restart_case "uncertain mutation outcome restarts and converges" uncertain
permanent_mutation_failure_case
lagged_list_case "lagging issue list after a mutation does not duplicate the create" 3 15 converge
lagged_list_case "mutation never visible fails closed without a second create" 50 3 fail
two_attempts_case
skipped_attempt_case
checkpoint_case "expired evidence before authenticated checkpoint permits replay" expired-pre-epoch
checkpoint_case "expired evidence after checkpoint fails before mutation" expired-in-epoch
checkpoint_case "tampered checkpoint fails before mutation" tampered
checkpoint_case "concurrent issue-history advancement invalidates checkpoint" concurrent-advance
checkpoint_case "repository retention cap below 14 days fails before mutation" short-retention
checkpoint_expiry_boundary_case 3599
checkpoint_expiry_boundary_case 3601

# Genesis: legacy scheduled runs predate verdict artifacts. The first run that
# carries a verdict artifact starts the replay cursor, and a single unmarked
# pre-genesis open incident is adopted as the current incident.
genesis_fixture() {
  local verdict="$1" temp
  temp="$(new_fixture)"
  jq '.workflow_runs = [
      {id:90,run_attempt:1,event:"schedule",status:"completed",conclusion:"failure",head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",head_branch:"main",html_url:"https://github.com/szTheory/rindle/actions/runs/90",name:"Nightly",path:".github/workflows/nightly.yml"},
      {id:91,run_attempt:1,event:"schedule",status:"completed",conclusion:"failure",head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",head_branch:"main",html_url:"https://github.com/szTheory/rindle/actions/runs/91",name:"Nightly",path:".github/workflows/nightly.yml"}
    ] + [.workflow_runs[-1]]' "${temp}/state/runs.json" >"${temp}/state/runs.next"
  mv "${temp}/state/runs.next" "${temp}/state/runs.json"
  write_artifacts "${temp}/state/artifacts.json" green-only
  write_event "${temp}/state/events/nightly-incident-verdict-103-1.json" 103 1 "${verdict}" "${sha_b}"
  jq -cn '[
    {number:36,title:"Nightly CI failure",state:"CLOSED",body:"Legacy Nightly failure",comments:[]},
    {number:88,title:"Nightly CI failure",state:"OPEN",body:"Legacy Nightly failure",comments:[{body:"Nightly failed again: run 91"}]}
  ]' >"${temp}/state/issues.json"
  printf '%s' "${temp}"
}

genesis_adopt_case() {
  local name="$1" verdict="$2" want_state="$3" want_marker="$4" temp output got=0 attempts=0 replay_attempts=0
  temp="$(genesis_fixture "${verdict}")"
  output="${temp}/output"
  run_manager "${temp}" "${output}" || got=$?
  [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -eq 0 ] && [ "${attempts}" -eq 1 ] && [ "$(jq length "${temp}/state/issues.json")" -eq 2 ] &&
     [ "$(jq -r '.[] | select(.number == 88) | .state' "${temp}/state/issues.json")" = "${want_state}" ] &&
     [ "$(jq -r --arg m "${want_marker}" '[.[] | select(.number == 88) | .comments[].body | select(contains($m) and contains("actions/runs/103"))] | length' "${temp}/state/issues.json")" -eq 1 ] &&
     [ "$(mutation_effects "${temp}")" -eq 1 ] &&
     jq -e '.last_run_id == 103 and .issue_number == 88' "${temp}/state/checkpoint-output.json" >/dev/null; then
    record "${name}" true ""
  else
    record "${name}" false "exit=${got} attempts=${attempts}; $(<"${output}")"
  fi

  rm -f "${temp}/state/artifact_reads" "${temp}/state/issue_reads" "${temp}/state/mutation_attempts"
  got=0
  run_manager "${temp}" "${output}" || got=$?
  [ ! -f "${temp}/state/mutation_attempts" ] || replay_attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -eq 0 ] && [ "${replay_attempts}" -eq 0 ] && [ "$(mutation_effects "${temp}")" -eq 1 ]; then
    record "${name}: re-run on the same run is mutation-idempotent" true ""
  else
    record "${name}: re-run on the same run is mutation-idempotent" false "exit=${got} attempts=${replay_attempts}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

genesis_fail_closed_case() {
  local name="$1" setup="$2" reason="$3" temp output got=0 attempts=0
  temp="$(genesis_fixture green)"
  output="${temp}/output"
  case "${setup}" in
    duplicate-open)
      jq '. + [{number:89,title:"Nightly CI failure",state:"OPEN",body:"Legacy Nightly failure",comments:[]}]' \
        "${temp}/state/issues.json" >"${temp}/state/issues.next"
      mv "${temp}/state/issues.next" "${temp}/state/issues.json"
      ;;
    unlabelled)
      jq -cn '[{number:88,title:"Nightly CI failure",labels:[{name:"nightly-failure"}]},{number:95,title:"Nightly CI failure",labels:[]}]' \
        >"${temp}/state/title-search.json"
      ;;
    pre-genesis-marker)
      jq '(.[] | select(.number == 88) | .comments) += [{body:"Evidence marker: nightly-mutation:update:91:1"}]' \
        "${temp}/state/issues.json" >"${temp}/state/issues.next"
      mv "${temp}/state/issues.next" "${temp}/state/issues.json"
      ;;
    missing-post-genesis)
      jq '.workflow_runs = [.workflow_runs[0], .workflow_runs[1],
          (.workflow_runs[2] | .id = 101 | .status = "completed" | .conclusion = "failure" | .head_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" | .html_url = "https://github.com/szTheory/rindle/actions/runs/101"),
          (.workflow_runs[2] | .id = 102 | .status = "completed" | .conclusion = "failure" | .head_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" | .html_url = "https://github.com/szTheory/rindle/actions/runs/102"),
          .workflow_runs[2]]' "${temp}/state/runs.json" >"${temp}/state/runs.next"
      mv "${temp}/state/runs.next" "${temp}/state/runs.json"
      write_artifacts "${temp}/state/artifacts.json" missing-middle
      ;;
  esac
  run_manager "${temp}" "${output}" || got=$?
  [ ! -f "${temp}/state/mutation_attempts" ] || attempts="$(<"${temp}/state/mutation_attempts")"
  if [ "${got}" -ne 0 ] && [ "${attempts}" -eq 0 ] && grep -Fq -- "${reason}" "${output}"; then
    record "${name}" true ""
  else
    record "${name}" false "expected pre-mutation failure '${reason}', got exit=${got} attempts=${attempts}; $(<"${output}")"
  fi
  rm -rf "${temp}"
}

genesis_adopt_case "genesis adopts the legacy open incident and closes it citing the green run" green CLOSED "nightly-mutation:close:103:1"
genesis_adopt_case "genesis adopts the legacy open incident and updates it citing the red run" red OPEN "nightly-mutation:update:103:1"
genesis_fail_closed_case "genesis with duplicate legacy open incidents fails closed" duplicate-open "competing exact-label incident inventory"
genesis_fail_closed_case "genesis with an unlabelled open incident fails closed" unlabelled "lacks the nightly-failure label"
genesis_fail_closed_case "genesis with a mutation marker before the genesis run fails closed" pre-genesis-marker "predates the genesis run 103/1"
genesis_fail_closed_case "a missing verdict artifact after genesis still fails closed" missing-post-genesis "coverage incomplete"

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${pass}" -gt 0 ]
[ "${fail}" -eq 0 ]
