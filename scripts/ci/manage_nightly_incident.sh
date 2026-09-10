#!/usr/bin/env bash
# Thin GitHub Issues adapter for eval_nightly_incident.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
evaluator="${here}/eval_nightly_incident.sh"

: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${GH_REPO:?GH_REPO must be set}"

incident_label="${INCIDENT_LABEL:-nightly-failure}"
incident_title="${INCIDENT_TITLE:-Nightly CI failure}"
[ "${incident_label}" = nightly-failure ] || { echo "unexpected incident label" >&2; exit 1; }
[ "${incident_title}" = "Nightly CI failure" ] || { echo "unexpected incident title" >&2; exit 1; }
[[ "${GH_REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "invalid GH_REPO" >&2
  exit 1
}

# Query the complete exact-label set immediately before deciding on a mutation.
open_incidents_json="$(
  gh issue list --repo "${GH_REPO}" --state open --label "${incident_label}" \
    --limit 100 --json number,title,body,comments
)"

decision="$(OPEN_INCIDENTS_JSON="${open_incidents_json}" bash "${evaluator}")"
case "${decision}" in open|update|close|noop) ;; *) echo "invalid evaluator decision" >&2; exit 1 ;; esac

if [ "${decision}" = noop ]; then
  echo "Nightly incident lifecycle: no mutation"
  exit 0
fi

issue_number="$(jq -r 'if length == 1 then .[0].number else empty end' <<<"${open_incidents_json}")"
if [ "${decision}" != open ] && ! [[ "${issue_number}" =~ ^[1-9][0-9]*$ ]]; then
  echo "incident number missing for ${decision}" >&2
  exit 1
fi

body_file="${INCIDENT_BODY_FILE:-$(mktemp)}"
cleanup_body=false
[ -n "${INCIDENT_BODY_FILE-}" ] || cleanup_body=true
if [ "${cleanup_body}" = true ]; then
  trap 'rm -f "${body_file}"' EXIT
fi

{
  printf 'Nightly verdict: %s\n\n' "${NIGHTLY_VERDICT}"
  printf 'Run: %s\n' "${RUN_URL}"
  printf 'Run ID: %s\n' "${RUN_ID}"
  printf 'Run attempt: %s\n' "${RUN_ATTEMPT}"
  printf 'Run SHA: %s\n' "${RUN_SHA}"
  printf 'Evidence marker: nightly-run:%s:%s\n' "${RUN_ID}" "${RUN_ATTEMPT}"
} >"${body_file}"

case "${decision}" in
  open)
    gh issue create --repo "${GH_REPO}" --title "${incident_title}" \
      --label "${incident_label}" --body-file "${body_file}"
    ;;
  update)
    gh issue comment "${issue_number}" --repo "${GH_REPO}" --body-file "${body_file}"
    ;;
  close)
    gh issue close "${issue_number}" --comment "$(<"${body_file}")" --repo "${GH_REPO}"
    ;;
esac
