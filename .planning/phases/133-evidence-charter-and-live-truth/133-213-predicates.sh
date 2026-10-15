#!/usr/bin/env bash
# Plan 213 per-requirement predicates. Read-only against GitHub; each prints PASS/FAIL and the
# script exits non-zero if any predicate fails. Inputs are pinned below.
set -uo pipefail

REPO=szTheory/rindle
MERGE_SHA=ecd4d5a091d9cf3a8f0cf686cf35df7f24e1c03a
PUSH_RUN=38667117452
RECEIPTS=".planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-SCHEDULED-RECEIPTS.json"
CENSUS_LEDGER=".planning/phases/133-evidence-charter-and-live-truth/133-213-CENSUS-LEDGER.json"
CENSUS_RECEIPT=".planning/phases/133-evidence-charter-and-live-truth/133-213-CENSUS-RECEIPT.json"
CENSUS_ROOT="${CENSUS_ROOT:?set CENSUS_ROOT to a clean checkout of the receipt SHA}"

receipt="$(jq '.[-1]' "$RECEIPTS")"
fails=0
verdict() { if [ "$2" -eq 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

step_ok() { # job, step-regex
  gh api "repos/${REPO}/actions/runs/${PUSH_RUN}/jobs" --paginate \
    --jq ".jobs[] | select(.name == \"$1\") | select(.conclusion == \"success\") | .steps[] | select(.name | test(\"$2\")) | .conclusion" |
    grep -qx success
}

push_ok() {
  [ "$(gh run view "$PUSH_RUN" --repo "$REPO" --json headSha,event,conclusion --jq '"\(.headSha) \(.event) \(.conclusion)"')" = "${MERGE_SHA} push success" ]
}

# EVID-01: the census regenerated at the receipt SHA validates.
sha="$(jq -r .head_sha <<<"$receipt")"
[ "$(git -C "$CENSUS_ROOT" rev-parse HEAD)" = "$sha" ] && [ -z "$(git -C "$CENSUS_ROOT" status --porcelain)" ] &&
  (cd "$CENSUS_ROOT" && mix run --no-compile --no-start scripts/maintainer/validate_evidence_census.exs \
    --root "$CENSUS_ROOT" --ledger "$OLDPWD/$CENSUS_LEDGER" --receipt "$OLDPWD/$CENSUS_RECEIPT")
verdict EVID-01 $?

# EVID-02: every supported Dialyzer job succeeded, and the merge push run ran the Dialyzer harness green.
jq -e '[.jobs[] | select(.name | test("^Dialyzer"))] | length > 0 and all(.conclusion == "success")' <<<"$receipt" >/dev/null &&
  push_ok && step_ok Proof "Nightly evidence harnesses"
verdict EVID-02 $?

# EVID-03: the verdict artifact agrees with Nightly Summary and with each gating job conclusion,
# and the merge push run ran the summary-gate harness green.
jq -e '
  def jobs($p): [.jobs[] | select(.name | startswith($p)) | .conclusion];
  def agg($p): (jobs($p) | if length == 0 then "missing" elif all(. == "success") then "success" else "failure" end);
  (.verdict_artifact.verdict.verdict == .verdict) and
  ((.verdict == "green") == ([.jobs[] | select(.name == "Nightly Summary") | .conclusion] == ["success"])) and
  (.verdict_artifact.verdict.jobs | map({(.name): .result}) | add) as $art |
  ($art["compat-matrix"] == agg("Compat Matrix")) and
  ($art["dialyzer"] == agg("Dialyzer")) and
  ($art["gcs-soak"] == agg("GCS Soak")) and
  ($art["package-consumer-gcs-live"] == agg("Package Consumer GCS Live Proof")) and
  (.gating_needs == $art)
' <<<"$receipt" >/dev/null &&
  push_ok && step_ok "CI Script Tests" "Nightly Summary gate logic" && step_ok Proof "Nightly evidence harnesses"
verdict EVID-03 $?

# EVID-04: green receipt -> the adopted incident is closed by a comment citing the run, none open.
run_id="$(jq -r .run_id <<<"$receipt")"
[ "$(jq -r .verdict <<<"$receipt")" = green ] &&
  [ "$(gh issue list --repo "$REPO" --label nightly-failure --state open --json number --jq length)" = 0 ] &&
  [ "$(gh issue list --repo "$REPO" --state open --search 'in:title "Nightly CI failure"' --json number --jq length)" = 0 ] &&
  gh issue view 88 --repo "$REPO" --json state,comments \
    --jq "select(.state == \"CLOSED\") | .comments[].body" | grep -q "nightly-mutation:close:${run_id}:1"
verdict EVID-04 $?

# TRUTH-08: the merge push run is green on every merge-blocking job, including the adoption matrix gate
# (which runs live_truth_parity_test's derived and package authority proofs).
push_ok &&
  gh api "repos/${REPO}/actions/runs/${PUSH_RUN}/jobs" --paginate \
    --jq '[.jobs[] | select(.name | test("^(Quality|Integration|Proof|Package Consumer Proof Matrix|Adopter|CI Summary)")) | .conclusion] | (length >= 7) and all(. == "success")' |
  grep -qx true &&
  step_ok Proof "adoption proof matrix drift gate"
verdict TRUTH-08 $?

exit "$fails"
