#!/usr/bin/env bash
# test_craft_contract_tools.sh - fixture harness for the readability contract tools:
#   scripts/maintainer/validate_readability_trace.sh
# One failing fixture per rejection rule plus clean fixtures. Needs only bash, jq, git and
# coreutils: no network, no gh, no Elixir. Bash 3.2 / jq 1.6 compatible.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRACE_VALIDATOR="${ROOT}/scripts/maintainer/validate_readability_trace.sh"
TRACE="${ROOT}/scripts/maintainer/readability_changes.json"
T="$(mktemp -d)"
trap 'chmod -R u+w "${T}" 2>/dev/null; rm -rf "${T}"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

verdict() {
  local name="$1" rc="$2" want="$3" pat="$4"
  if [ "${rc}" != "${want}" ]; then
    bad "${name} (exit ${rc}, want ${want}): $(tr '\n' '|' <"${T}/err")"
  elif [ -n "${pat}" ] && ! grep -qF -- "${pat}" "${T}/err"; then
    bad "${name} (missing reason text: ${pat}): $(tr '\n' '|' <"${T}/err")"
  else
    ok "${name}"
  fi
}

gitq() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false "$@"; }

# --- trace fixtures -----------------------------------------------------------------------
ANCHOR='{"check": "Credo.Check.Refactor.CyclomaticComplexity", "file": "lib/sample/widget.ex", "trigger": "render", "observed_metric": 12}'
KEPT='{"check": "Credo.Check.Refactor.CyclomaticComplexity", "file": "lib/sample/other.ex", "trigger": "parse", "observed_metric": 11}'

jq -n --argjson a "${ANCHOR}" --argjson k "${KEPT}" \
  '{entries: [($a + {count: 1, owner: "sample", removal_trigger: "sample"}), ($k + {count: 1, owner: "sample", removal_trigger: "sample"})]}' \
  >"${T}/baseline_before.json"
jq -n --argjson k "${KEPT}" '{entries: [($k + {count: 1, owner: "sample", removal_trigger: "sample"})]}' \
  >"${T}/baseline_after.json"

jq -S --argjson a "${ANCHOR}" '.changes = [{
    id: "widget-render-split",
    candidate_id: "quality-maintainability-curated-complexity",
    detector: "credo complexity baseline",
    anchor: $a,
    files: ["lib/sample/widget.ex"],
    intent: "cohesion",
    proof: ["mix credo_quality", "bash scripts/maintainer/refactor_contract.sh"],
    pr: null
  }]' "${TRACE}" >"${T}/trace_one.json"

# trace NAME TRACE_FILTER BASELINE EXPECT_EXIT PATTERN
trace() {
  local name="$1" tf="$2" baseline="$3" want="$4" pat="$5"
  jq -S "${tf}" "${T}/trace_one.json" >"${T}/t.json"
  local rc=0
  bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${baseline}" >"${T}/out" 2>"${T}/err" || rc=$?
  verdict "${name}" "${rc}" "${want}" "${pat}"
}

AFTER="${T}/baseline_after.json"
BEFORE="${T}/baseline_before.json"

rc=0
bash "${TRACE_VALIDATOR}" --offline --trace "${TRACE}" \
  --baseline "${ROOT}/scripts/maintainer/credo_complexity_baseline.json" >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace: committed trace passes offline" "${rc}" 0 ""

trace "trace: one traced change passes offline" '.' "${AFTER}" 0 ""
trace "trace: sha256 altered" '.candidate_ledger.sha256 = ("0" * 64)' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: subject_sha altered" '.candidate_ledger.subject_sha = ("1" * 40)' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: candidate id list altered" '.candidate_ledger.candidate_ids += ["quality-invented"]' "${AFTER}" 1 "REJECT: ledger identity"
trace "trace: schema altered" '.schema = "other"' "${AFTER}" 1 "REJECT: schema"
trace "trace: candidate_id outside the pinned ids" '.changes[0].candidate_id = "quality-invented"' "${AFTER}" 1 "REJECT: candidate"
trace "trace: intent style" '.changes[0].intent = "style"' "${AFTER}" 1 "REJECT: intent"
trace "trace: empty proof" '.changes[0].proof = []' "${AFTER}" 1 "REJECT: proof"
trace "trace: empty files" '.changes[0].files = []' "${AFTER}" 1 "REJECT: files"
trace "trace: blank detector" '.changes[0].detector = " "' "${AFTER}" 1 "REJECT: detector"
trace "trace: pr not an integer" '.changes[0].pr = "42"' "${AFTER}" 1 "REJECT: pr"
trace "trace: pr integer accepted" '.changes[0].pr = 42' "${AFTER}" 0 ""
trace "trace: anchor missing a key" '.changes[0].anchor |= del(.trigger)' "${AFTER}" 1 "REJECT: anchor"
trace "trace: duplicate change id" '.changes += [.changes[0]]' "${AFTER}" 1 "REJECT: duplicate id"
trace "trace: anchor still present in the baseline" '.' "${BEFORE}" 1 "REJECT: anchor present"
trace "trace: changes not an array" '.changes = {}' "${AFTER}" 1 "REJECT: changes"

# all reasons in one run
jq -S '.changes[0].intent = "style" | .changes[0].candidate_id = "x" | .candidate_ledger.sha256 = "y"' \
  "${T}/trace_one.json" >"${T}/t.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
if [ "${rc}" = 1 ] && [ "$(grep -c '^REJECT: ' "${T}/err")" -ge 3 ]; then ok "trace: every reason reported in one run"; else bad "trace: all reasons (rc ${rc}): $(tr '\n' '|' <"${T}/err")"; fi

# unreadable and usage
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/absent.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: missing trace file" "${rc}" 1 "REJECT: unreadable"
printf '{not json' >"${T}/broken.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/broken.json" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: invalid JSON trace" "${rc}" 1 "REJECT: unreadable"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${TRACE}" --baseline "${AFTER}" --bogus >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: unknown flag is a usage error" "${rc}" 64 "unknown argument"
rc=0; bash "${TRACE_VALIDATOR}" --trace "${TRACE}" --baseline "${AFTER}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: missing mode is a usage error" "${rc}" 64 ""

# --verify-source
printf 'not the ledger\n' >"${T}/ledger_copy.json"
rc=0; bash "${TRACE_VALIDATOR}" --verify-source "${T}/ledger_copy.json" --trace "${TRACE}" >/dev/null 2>"${T}/err" || rc=$?
verdict "trace: verify-source rejects a different file" "${rc}" 1 "REJECT: source sha256"

# --- --base against a real git history ----------------------------------------------------
R="${T}/repo"
mkdir -p "${R}/scripts/maintainer"
gitq -C "${R}" init -q
cp "${BEFORE}" "${R}/scripts/maintainer/credo_complexity_baseline.json"
gitq -C "${R}" add scripts/maintainer/credo_complexity_baseline.json
gitq -C "${R}" commit -q -m base
cp "${AFTER}" "${R}/scripts/maintainer/credo_complexity_baseline.json"

rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base HEAD --trace "${T}/trace_one.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: anchor removed since base passes" "${rc}" 0 ""

jq -S '.changes[0].anchor.observed_metric = 99' "${T}/trace_one.json" >"${T}/t.json"
rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base HEAD --trace "${T}/t.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: anchor absent at base" "${rc}" 1 "REJECT: anchor not in base"

rc=0
(cd "${R}" && bash "${TRACE_VALIDATOR}" --base no-such-ref --trace "${T}/trace_one.json" \
  --baseline scripts/maintainer/credo_complexity_baseline.json) >"${T}/out" 2>"${T}/err" || rc=$?
verdict "trace --base: unknown ref is rejected" "${rc}" 1 "REJECT: base"

# --- untrusted text is never executed -----------------------------------------------------
INJ="${T}/pwned"
jq -S --arg c "\$(touch ${INJ})" \
  '.changes[0].id = $c | .changes[0].detector = ("`touch " + $c + "`") | .changes[0].intent = $c | .changes[0].proof = [$c]' \
  "${T}/trace_one.json" >"${T}/t.json"
rc=0; bash "${TRACE_VALIDATOR}" --offline --trace "${T}/t.json" --baseline "${AFTER}" >/dev/null 2>&1 || rc=$?
if [ ! -e "${INJ}" ] && [ "${rc}" = 1 ]; then ok "trace: shell substitution text is data, never executed"; else bad "trace injection (rc ${rc}, file exists: $([ -e "${INJ}" ] && echo yes || echo no))"; fi

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
