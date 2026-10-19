#!/usr/bin/env bash
# test_validate_inbox_ledger.sh - fixture harness for scripts/maintainer/validate_inbox_ledger.sh
# (inbox ledger shape, security disposition and dependency landing rules). One failing
# fixture per rejection rule plus clean
# fixtures. Needs only bash, jq and coreutils: no network, no gh, no Elixir.
# Clock injection: INBOX_NOW_EPOCH. Bash 3.2 / jq 1.6 compatible.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${ROOT}/scripts/maintainer/validate_inbox_ledger.sh"
T="$(mktemp -d)"
trap 'chmod -R u+w "${T}" 2>/dev/null; rm -rf "${T}"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

TWIN='not-applicable: twin not built (Phase 137)'
HEAD105="1111111111111111111111111111111111111111"
NOW="$(jq -n '"2026-10-15T13:00:00Z" | fromdateiso8601')"

# --- base fixtures ----------------------------------------------------------------------
cat >"${T}/base_inv.json" <<EOF
{
  "schema": "rindle-inbox-inventory-v1",
  "repo": "szTheory/rindle",
  "collected_at": "2026-10-15T12:00:00Z",
  "main_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "issues": [{"number": 42, "title": "flaky", "labels": [], "updated_at": "2026-08-28T00:00:00Z"}],
  "prs": [{
    "number": 105, "head_sha": "${HEAD105}", "base": "main", "behind": false,
    "mergeable": true, "mergeable_state": "clean",
    "ci_summary": {"conclusion": "success", "completed_at": "2026-10-15T11:00:00Z", "superseded_count": 0},
    "manifest_files": ["mix.lock"],
    "lock_delta": [{"lock": "mix.lock", "package": "ecto", "from": "3.13.6", "to": "3.14.2"},
                   {"lock": "mix.lock", "package": "ecto_sql", "from": "3.13.5", "to": "3.14.0"}]
  }],
  "terminal": [{"kind": "pr", "number": 93, "state": "closed", "state_reason": null, "merged": false}],
  "hex_latest": {"bandit": "1.12.5"},
  "advisories": {
    "findings": [
      {"id": "EEF-CVE-2026-97853", "package": "decimal", "scope": "root", "version": "3.1.1", "ignored": false, "severity": "MEDIUM", "source": "hex_audit"},
      {"id": "EEF-CVE-2026-105659", "package": "bandit", "scope": "examples/adoption_demo", "version": "1.12.5", "ignored": false, "severity": "HIGH", "source": "hex_audit"}
    ],
    "sources": {
      "hex_audit_root": {"status": "findings"},
      "hex_audit_demo": {"status": "findings"},
      "deps_audit": {"status": "clean"},
      "dependabot_alerts": {"status": "source_disabled", "http": 403},
      "vulnerability_alerts": {"status": "source_disabled", "http": 404},
      "actions": {"status": "not-applicable"}
    }
  }
}
EOF

cat >"${T}/base_ledger.json" <<EOF
{
  "schema": "rindle-inbox-ledger-v1",
  "repo": "szTheory/rindle",
  "items": [
    {"kind": "issue", "number": 42, "disposition": "retain", "rationale": "evidence-gated"},
    {"kind": "pr", "number": 105, "disposition": "merge", "head_sha": "${HEAD105}",
     "risk_group": "ecto_sql", "group_packages": ["ecto", "ecto_sql"], "rationale": "runtime core minor"},
    {"kind": "pr", "number": 93, "disposition": "close", "rationale": "superseded",
     "terminal": {"state": "closed", "merged": false, "state_reason": null}}
  ],
  "advisories": [
    {"id": "EEF-CVE-2026-97853", "package": "decimal", "locked": "3.1.1", "scope": "root",
     "path": ["ecto_sql", "decimal"], "reachability": "runtime", "fix_version": "3.1.2",
     "status": "exception",
     "exception": {"expires": "2026-12-31", "trigger": {"type": "date", "not_after": "2026-12-31"}, "rationale": "fix PR queued"}},
    {"id": "EEF-CVE-2026-105659", "package": "bandit", "locked": "1.12.5", "scope": "examples/adoption_demo",
     "path": ["bandit"], "reachability": "dev-test-only", "fix_version": null,
     "status": "exception",
     "exception": {"expires": "2026-11-30", "trigger": {"type": "hex_version_gte", "package": "bandit", "version": "1.12.6"}, "rationale": "demo only, no released fix"}},
    {"id": "EEF-CVE-2026-00001", "package": "mint", "locked": "1.9.3", "scope": "root",
     "path": ["req", "mint"], "reachability": "optional-dep", "fix_version": "1.10.2", "status": "resolved"}
  ],
  "sources": {"dependabot_alerts": {"status": "source_disabled", "rationale": "dependency graph does not parse mix.lock"}},
  "landings": [
    {"number": 105, "group": "ecto_sql", "group_packages": ["ecto", "ecto_sql"], "lock": "mix.lock",
     "merge_sha": "2222222222222222222222222222222222222222", "ci_run_id": 100, "baseline_run_id": 99,
     "lock_delta": [{"package": "ecto", "from": "3.13.6", "to": "3.14.2"}],
     "gates": {"supported_toolchain": "pass", "public_contract": "pass", "package_consumer": "pass", "twin": "${TWIN}"},
     "subject": "build(deps): bump ecto_sql"}
  ]
}
EOF

# live NAME LEDGER_FILTER INV_FILTER EXPECT_EXIT PATTERN [NOW_EPOCH]
live() {
  local name="$1" lf="$2" iff="$3" want="$4" pat="$5" now="${6:-$NOW}"
  jq -S "${lf}" "${T}/base_ledger.json" >"${T}/l.json"
  jq -S "${iff}" "${T}/base_inv.json" >"${T}/i.json"
  local rc=0
  INBOX_NOW_EPOCH="${now}" bash "${VALIDATOR}" --ledger "${T}/l.json" --inventory "${T}/i.json" >"${T}/out" 2>"${T}/err" || rc=$?
  verdict "${name}" "${rc}" "${want}" "${pat}"
}

# offline NAME LEDGER_FILTER EXPECT_EXIT PATTERN
offline() {
  local name="$1" lf="$2" want="$3" pat="$4"
  jq -S "${lf}" "${T}/base_ledger.json" >"${T}/l.json"
  local rc=0
  bash "${VALIDATOR}" --ledger "${T}/l.json" --offline >"${T}/out" 2>"${T}/err" || rc=$?
  verdict "${name}" "${rc}" "${want}" "${pat}"
}

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

ID='.'

# --- Task 1: open-item coverage ---------------------------------------------------------
live "live: clean fixtures exit 0" "${ID}" "${ID}" 0 ""
live "live: missing PR 105 rejected" 'del(.items[] | select(.number == 105))' "${ID}" 1 "REJECT: missing: pr 105"
live "live: missing issue 42 rejected" 'del(.items[] | select(.number == 42))' "${ID}" 1 "REJECT: missing: issue 42"
live "live: duplicate issue 42 rejected" '.items += [.items[0]]' "${ID}" 1 "REJECT: duplicate: issue 42"
live "live: repo mismatch rejected" "${ID}" '.repo = "other/repo"' 1 "REJECT: repo"

# a run reports every problem, not just the first
jq -S 'del(.items[] | select(.number == 105)) | .items += [.items[0]]' "${T}/base_ledger.json" >"${T}/l.json"
rc=0
INBOX_NOW_EPOCH="${NOW}" bash "${VALIDATOR}" --ledger "${T}/l.json" --inventory "${T}/base_inv.json" >/dev/null 2>"${T}/err" || rc=$?
if [ "${rc}" = 1 ] && grep -q "REJECT: missing" "${T}/err" && grep -q "REJECT: duplicate" "${T}/err"; then
  ok "live: all problems reported in one run"
else
  bad "live: all problems reported in one run"
fi

# --- Task 2: remaining rules ------------------------------------------------------------
# freshness and staleness
live "live: stale PR head rejected" '(.items[] | select(.number == 105) | .head_sha) = "3333333333333333333333333333333333333333"' "${ID}" 1 "REJECT: stale: pr 105"
live "live: inventory older than bound rejected" "${ID}" "${ID}" 1 "REJECT: stale inventory" "$((NOW + 90000))"
live "live: custom --max-age-seconds accepted" "${ID}" "${ID}" 0 "" "$((NOW + 3000))"
live "live: inventory from the future rejected" "${ID}" '.collected_at = "2026-10-15T14:00:00Z"' 1 "REJECT: inventory: collected_at is in the future"
live "live: wrong inventory schema rejected" "${ID}" '.schema = "nope"' 1 "REJECT: inventory: schema"

# terminal records
live "live: item for non-open number without terminal rejected" '.items += [{"kind":"issue","number":77,"disposition":"retain","rationale":"x"}]' "${ID}" 1 "REJECT: not-open: issue 77"
live "live: terminal merged mismatch rejected" '(.items[] | select(.number == 93) | .terminal.merged) = true' "${ID}" 1 "REJECT: terminal mismatch"
live "live: terminal without inventory lookup rejected" "${ID}" '.terminal = []' 1 "REJECT: terminal mismatch"
live "live: terminal on a still-open item rejected" '(.items[] | select(.number == 42)) += {"terminal":{"state":"closed","merged":false}}' "${ID}" 1 "REJECT: terminal mismatch"

# disposition-specific fields
live "live: supersede without successor rejected" '(.items[] | select(.number == 42)) |= (.disposition = "supersede")' "${ID}" 1 "REJECT: supersede requires successor"
live "live: supersede with successor accepted" '(.items[] | select(.number == 42)) |= (.disposition = "supersede" | .successor = "#99")' "${ID}" 0 ""
live "live: defer without gate rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .trigger = {"type":"date","not_after":"2026-12-31"})' "${ID}" 1 "REJECT: defer requires gate"
live "live: defer without trigger rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "TEST-08")' "${ID}" 1 "REJECT: defer requires trigger"
live "live: defer trigger outside vocabulary rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"shell","cmd":"true"})' "${ID}" 1 "outside the closed vocabulary"
live "live: unknown disposition rejected" '(.items[] | select(.number == 42) | .disposition) = "ignore"' "${ID}" 1 "REJECT: unknown disposition"

# fired triggers
live "live: pending defer accepted" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"date","not_after":"2026-12-31"})' "${ID}" 0 ""
live "live: fired date trigger rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"date","not_after":"2026-10-01"})' "${ID}" 1 "REJECT: trigger fired"
live "live: misspelled trigger type rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"hex_hex","package":"bandit"})' "${ID}" 1 "closed vocabulary"
live "live: hex_version_gte satisfied by hex_latest rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"hex_version_gte","package":"bandit","version":"1.12.0"})' "${ID}" 1 "REJECT: trigger fired"
live "live: gh_issue_closed satisfied rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"gh_issue_closed","number":93})' "${ID}" 1 "REJECT: trigger fired"
live "live: unevaluable trigger rejected" '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"hex_version_gte","package":"nothere","version":"1.0.0"})' "${ID}" 1 "REJECT: trigger unevaluable"

# merge readiness and attribution
live "live: merge with failing CI Summary rejected" "${ID}" '(.prs[0].ci_summary.conclusion) = "failure"' 1 "REJECT: not mergeable"
live "live: merge behind main rejected" "${ID}" '(.prs[0].behind) = true' 1 "REJECT: not mergeable"
live "live: merge behind main with pending_action rebase accepted" '(.items[] | select(.number == 105)) += {"pending_action":"rebase"}' '(.prs[0].behind) = true' 0 ""
live "live: lock delta outside group_packages rejected" "${ID}" '.prs[0].lock_delta += [{"lock":"mix.lock","package":"mint","from":"1.9.3","to":"1.10.2"}]' 1 "REJECT: attribution"
live "live: unknown pending_action rejected" '(.items[] | select(.number == 105)) += {"pending_action":"yolo"}' "${ID}" 1 "pending_action must be"

# advisories
live "live: inventory finding without ledger record rejected" "${ID}" '.advisories.findings += [{"id":"EEF-CVE-2026-99999","package":"x","scope":"root","version":"1","ignored":false,"severity":"LOW","source":"hex_audit"}]' 1 "REJECT: advisory missing"
live "live: resolved record still reported rejected" '(.advisories[] | select(.id == "EEF-CVE-2026-97853")) |= (.status = "resolved" | del(.exception))' "${ID}" 1 "REJECT: advisory not resolved"
live "live: expired exception rejected" "${ID}" "${ID}" 1 "REJECT: exception expired" "$(jq -n '"2026-12-01T00:00:00Z" | fromdateiso8601')"
live "live: exception missing trigger rejected" 'del(.advisories[] | select(.id == "EEF-CVE-2026-97853") | .exception.trigger)' "${ID}" 1 "trigger is required"
live "live: open advisory record rejected" '(.advisories[] | select(.id == "EEF-CVE-2026-97853")) |= (.status = "open" | del(.exception))' "${ID}" 1 "REJECT: advisory open"
live "live: ledger record no longer reported and not resolved rejected" "${ID}" '.advisories.findings |= map(select(.package != "bandit"))' 1 "REJECT: advisory stale"
live "live: ignored finding needs an exception" '(.advisories[] | select(.id == "EEF-CVE-2026-97853")) |= (.status = "resolved" | del(.exception))' '(.advisories.findings[0].ignored) = true' 1 "REJECT: advisory ignored"
live "live: ignored finding with unexpired exception accepted" "${ID}" '(.advisories.findings[0].ignored) = true' 0 ""
live "live: fired exception trigger rejected" "${ID}" '.hex_latest.bandit = "1.12.6"' 1 "REJECT: trigger fired"
live "live: bad reachability enum rejected" '(.advisories[0].reachability) = "prod"' "${ID}" 1 "reachability must be"

# sources
live "live: dependabot disabled without ledger source record rejected" 'del(.sources.dependabot_alerts)' "${ID}" 1 "REJECT: source"
live "live: dependabot disabled with empty rationale rejected" '.sources.dependabot_alerts.rationale = ""' "${ID}" 1 "REJECT: source"
live "live: dependabot ledger status mismatch rejected" '.sources.dependabot_alerts.status = "unreadable"' "${ID}" 1 "REJECT: source"
live "live: dependabot enabled needs no ledger record" 'del(.sources.dependabot_alerts)' '.advisories.sources.dependabot_alerts = {"status":"clean"}' 0 ""
live "live: hex_audit_root unreadable rejected" "${ID}" '.advisories.sources.hex_audit_root = {"status":"unreadable"}' 1 "REJECT: source unreadable: hex_audit_root"
live "live: hex_audit_demo unreadable rejected" "${ID}" '.advisories.sources.hex_audit_demo = {"status":"unreadable","reason":"skipped"}' 1 "REJECT: source unreadable: hex_audit_demo"

# landings (shape, enforced in live too)
live "live: twin pass rejected" '.landings[0].gates.twin = "pass"' "${ID}" 1 "REJECT: landing twin"
live "live: non-pass gate rejected" '.landings[0].gates.public_contract = "fail"' "${ID}" 1 "REJECT: landing gate"
live "live: lock_delta outside group_packages rejected" '.landings[0].lock_delta += [{"package":"mint"}]' "${ID}" 1 "outside group_packages"
live "live: merge_sha not 40-hex rejected" '.landings[0].merge_sha = "abc123"' "${ID}" 1 "merge_sha must be 40-hex"

# --- offline mode -----------------------------------------------------------------------
offline "offline: clean ledger exit 0" "${ID}" 0 ""
offline "offline: open advisories and pending actions exit 0" '(.advisories[0]) |= (.status = "open" | del(.exception)) | (.items[] | select(.number == 105)) += {"pending_action":"rebase"}' 0 ""
offline "offline: unknown disposition rejected" '(.items[0].disposition) = "maybe"' 1 "REJECT: unknown disposition"
offline "offline: missing rationale rejected" 'del(.items[0].rationale)' 1 "rationale is required"
offline "offline: PR item without head_sha rejected" 'del(.items[] | select(.number == 105) | .head_sha)' 1 "head_sha"
offline "offline: unknown trigger type rejected" '(.advisories[0].exception.trigger) = {"type":"cron"}' 1 "closed vocabulary"
offline "offline: wrong schema id rejected" '.schema = "v2"' 1 "REJECT: schema"
offline "offline: advisory missing path rejected" 'del(.advisories[0].path)' 1 "path must be"
offline "offline: risk_group without group_packages rejected" 'del(.items[] | select(.number == 105) | .group_packages)' 1 "go together"
offline "offline: twin pass landing rejected" '.landings[0].gates.twin = "pass"' 1 "REJECT: landing twin"
offline "offline: empty landings accepted" '.landings = []' 0 ""

# offline never reads the clock: a fake date that always fails and an invalid epoch must not matter
mkdir -p "${T}/fakebin"
printf '#!/bin/sh\necho "date called" >&2\nexit 99\n' >"${T}/fakebin/date"
chmod +x "${T}/fakebin/date"
rc=0
PATH="${T}/fakebin:${PATH}" INBOX_NOW_EPOCH=not-a-number bash "${VALIDATOR}" --ledger "${T}/base_ledger.json" --offline >"${T}/out" 2>"${T}/err" || rc=$?
if [ "${rc}" = 0 ] && ! grep -q "date called" "${T}/err"; then ok "offline: reads no clock"; else bad "offline: reads no clock (exit ${rc})"; fi

# --- CLI --------------------------------------------------------------------------------
rc=0; bash "${VALIDATOR}" >/dev/null 2>&1 || rc=$?
[ "${rc}" = 64 ] && ok "cli: no arguments exits 64" || bad "cli: no arguments exits 64 (got ${rc})"
rc=0; bash "${VALIDATOR}" --ledger "${T}/base_ledger.json" >/dev/null 2>&1 || rc=$?
[ "${rc}" = 64 ] && ok "cli: neither --offline nor --inventory exits 64" || bad "cli: neither mode exits 64 (got ${rc})"
rc=0; bash "${VALIDATOR}" --ledger "${T}/base_ledger.json" --offline --inventory "${T}/base_inv.json" >/dev/null 2>&1 || rc=$?
[ "${rc}" = 64 ] && ok "cli: --offline with --inventory exits 64" || bad "cli: both modes exits 64 (got ${rc})"
rc=0; bash "${VALIDATOR}" --ledger "${T}/base_ledger.json" --offline --bogus >/dev/null 2>&1 || rc=$?
[ "${rc}" = 64 ] && ok "cli: unknown flag exits 64" || bad "cli: unknown flag exits 64 (got ${rc})"
echo "{ not json" >"${T}/broken.json"
rc=0; bash "${VALIDATOR}" --ledger "${T}/broken.json" --offline >/dev/null 2>"${T}/err" || rc=$?
{ [ "${rc}" = 1 ] && grep -q "REJECT: unreadable" "${T}/err"; } && ok "cli: malformed ledger JSON rejected" || bad "cli: malformed ledger JSON rejected (got ${rc})"
rc=0; bash "${VALIDATOR}" --ledger "${T}/nonexistent.json" --offline >/dev/null 2>"${T}/err" || rc=$?
{ [ "${rc}" = 1 ] && grep -q "REJECT: unreadable" "${T}/err"; } && ok "cli: missing ledger file rejected" || bad "cli: missing ledger file rejected (got ${rc})"

# --- --print-collector-args -------------------------------------------------------------
jq -S '(.items[] | select(.number == 42)) |= (.disposition = "defer" | .gate = "g" | .trigger = {"type":"gh_issue_closed","number":88})' "${T}/base_ledger.json" >"${T}/l.json"
jq -S '.advisories[1].exception.trigger = {"type":"hex_version_gte","package":"bandit","version":"1.12.6"}' "${T}/l.json" >"${T}/l2.json"
rc=0; bash "${VALIDATOR}" --print-collector-args --ledger "${T}/l2.json" >"${T}/out" 2>"${T}/err" || rc=$?
if [ "${rc}" = 0 ] && [ "$(tr '\n' ' ' <"${T}/out")" = "--include 88 --include 93 --hex-package bandit " ]; then
  ok "print-collector-args: one --include per terminal/closed-trigger number and --hex-package per version trigger"
else
  bad "print-collector-args output: $(tr '\n' ' ' <"${T}/out")"
fi

# --- untrusted text is never executed ---------------------------------------------------
INJ="${T}/pwned"
jq -S --arg c "\$(touch ${INJ})" '(.items[0].rationale) = $c | (.items[0].gate) = ("`touch " + $c + "`") | (.advisories[0].exception.trigger) = {"type": $c}' "${T}/base_ledger.json" >"${T}/l.json"
rc=0; bash "${VALIDATOR}" --ledger "${T}/l.json" --offline >/dev/null 2>&1 || rc=$?
if [ ! -e "${INJ}" ] && [ "${rc}" = 1 ]; then ok "ledger text is data: shell and trigger injection not executed"; else bad "ledger injection (rc ${rc}, file exists: $([ -e "${INJ}" ] && echo yes || echo no))"; fi

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
