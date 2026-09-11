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
  local path="$1" mode="${2:-all}"
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
    '  cp "${state}/events/${name}.json" "${dir}/nightly-incident-verdict.json"' \
    '  exit 0' \
    'fi' \
    'if [ "${1-} ${2-}" = "issue list" ]; then' \
    '  [ "${FAKE_GH_FAIL-}" != list ] || exit 45' \
    '  n="$(counter issue_reads)"' \
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
    '  mv "${state}/issues.next" "${state}/issues.json"' \
    '  [ "${uncertain}" = false ] || exit 48' \
    '  exit 0' \
    'fi' \
    'exit 49' >"${bin_dir}/gh"
  chmod +x "${bin_dir}/gh"
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
    REMOTE_MAIN_SHA="${sha_b}" \
    NIGHTLY_REPLAY_SLEEP_SECONDS=0 NIGHTLY_REPLAY_FETCH_ATTEMPTS=3 NIGHTLY_REPLAY_MAX_RESTARTS=20 \
    "$@" bash "${manager}" >"${output}" 2>&1
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
  b_count="$({ rg -o 'nightly-mutation:update:102:1' "${temp}/state/issues.json" || true; } | wc -l | tr -d ' ')"
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
  if [ "${got}" -eq 0 ] && [ "$(jq length "${temp}/state/issues.json")" -eq 0 ] && ! rg -q 'nightly-mutation:' "${temp}/state/issues.json"; then
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

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${pass}" -gt 0 ]
[ "${fail}" -eq 0 ]
