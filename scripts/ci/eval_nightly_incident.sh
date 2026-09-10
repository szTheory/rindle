#!/usr/bin/env bash
# Pure scheduled Nightly incident policy. Prints one of open|update|close|noop.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[eval-nightly-incident] jq is required" >&2
  exit 1
fi

event_name="${EVENT_NAME-}"
verdict="${NIGHTLY_VERDICT-}"
run_id="${RUN_ID-}"
run_attempt="${RUN_ATTEMPT-}"
run_url="${RUN_URL-}"
run_sha="${RUN_SHA-}"
run_ref="${RUN_REF-}"
default_branch="${DEFAULT_BRANCH-}"
remote_main_sha="${REMOTE_MAIN_SHA-}"
incidents_json="${OPEN_INCIDENTS_JSON-}"

fail() {
  echo "[eval-nightly-incident] $1" >&2
  exit 1
}

case "${event_name}" in schedule|workflow_dispatch) ;; *) fail "invalid EVENT_NAME" ;; esac
case "${verdict}" in red|green) ;; *) fail "invalid NIGHTLY_VERDICT" ;; esac
[[ "${run_id}" =~ ^[1-9][0-9]{0,19}$ ]] || fail "invalid RUN_ID"
[[ "${run_attempt}" =~ ^[1-9][0-9]{0,9}$ ]] || fail "invalid RUN_ATTEMPT"
[[ "${run_url}" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/${run_id}$ ]] ||
  fail "invalid RUN_URL"
[[ "${run_sha}" =~ ^[0-9a-f]{40}$ ]] || fail "invalid RUN_SHA"
[[ "${remote_main_sha}" =~ ^[0-9a-f]{40}$ ]] || fail "invalid REMOTE_MAIN_SHA"
[[ "${default_branch}" =~ ^[A-Za-z0-9._/-]{1,100}$ ]] || fail "invalid DEFAULT_BRANCH"
[[ "${run_ref}" =~ ^refs/heads/[A-Za-z0-9._/-]{1,100}$ ]] || fail "invalid RUN_REF"

jq -e '
  type == "array" and
  all(.[];
    type == "object" and
    (.number | (type == "number" and . > 0 and floor == .)) and
    (.title | type == "string") and
    (.body | type == "string") and
    (.comments | type == "array") and
    all(.comments[]; type == "object" and (.body | type == "string"))
  )
' >/dev/null 2>&1 <<<"${incidents_json}" || fail "invalid OPEN_INCIDENTS_JSON"

incident_count="$(jq 'length' <<<"${incidents_json}")"
[ "${incident_count}" -le 1 ] || fail "multiple open nightly-failure incidents"

if [ "${incident_count}" -eq 1 ] &&
   [ "$(jq -r '.[0].title' <<<"${incidents_json}")" != "Nightly CI failure" ]; then
  fail "open nightly-failure incident has an unexpected title"
fi

# Diagnostic runs and anything not bound to the fresh default-branch head are read-only.
if [ "${event_name}" != schedule ] ||
   [ "${run_ref}" != "refs/heads/${default_branch}" ] ||
   [ "${run_sha}" != "${remote_main_sha}" ]; then
  echo noop
  exit 0
fi

marker="nightly-run:${run_id}:${run_attempt}"
if jq -e --arg marker "${marker}" \
  'any(.[]; (.body | contains($marker)) or any(.comments[]; .body | contains($marker)))' \
  >/dev/null <<<"${incidents_json}"; then
  echo noop
  exit 0
fi

case "${verdict}:${incident_count}" in
  red:0) echo open ;;
  red:1) echo update ;;
  green:1) echo close ;;
  green:0) echo noop ;;
  *) fail "unreachable incident policy state" ;;
esac
