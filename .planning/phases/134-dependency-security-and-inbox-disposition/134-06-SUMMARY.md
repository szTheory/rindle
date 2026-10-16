---
phase: 134-dependency-security-and-inbox-disposition
plan: 06
subsystem: deps
tags: [ledger, advisories, live-validation, nightly]
status: complete

requires:
  - phase: 134-05
    provides: batch B landings
provides:
  - "Live collector + validator pass on fresh data (inventory collected 2026-10-16T12:39:19Z): validate_inbox_ledger: ok (live)"
  - "REQUIREMENTS.md: INBOX-01, INBOX-02, SEC-09, DEPS-01 marked complete from that run"
affects: [phase-134-verification]

requirements-completed: [INBOX-01, INBOX-02, SEC-09, DEPS-01]
---

# Plan 134-06 Summary: closure

## Task 1 decisions (action permission only, D-134-05)

1. #95 (MuonTrap 2): no close needed. Dependabot closed it on 2026-10-15 after the semver-major ignore landed;
   the ledger records `close` with terminal `{state: closed, merged: false}`.
2. Dependabot alerts: left disabled. GitHub's dependency graph does not parse `mix.lock`, so enabling adds no Hex
   coverage; `sources.dependabot_alerts` stays `source_disabled` with that rationale.

## Task 2: advisories and live validation

- bandit (demo): **resolved, not an exception** (deviation from the plan's bounded exception). bandit 1.13.0 fixes
  both EEF-CVE-2026-105659 and the newly reported EEF-CVE-2026-105660, and rindle already handles Bandit >= 1.13's
  stale-conn check (#124), so PR #130 bumped the demo to 1.13.1. Landing: d6074a4c, main run 38898465466 (attempt 2;
  attempt 1 red only in the mux-lane AV timeout flake, todos/pending/2026-10-16-mux-lane-av-subprocess-timeout.md).
  The plan's jq check for `status=="exception"` on 105659 therefore does not apply; `[.advisories[] |
  select(.status=="open")] | length == 0` is true.
- cowlib (root): dated exception to 2027-01-15 (Plan 05).
- Live run: `collect_inbox.sh --out closure.json $(validate_inbox_ledger.sh --print-collector-args)` exit 0, then
  `validate_inbox_ledger.sh --inventory closure.json` exit 0 (`ok (live)`), inventory 2026-10-16T12:39:19Z.
  Root `mix hex.audit`: cowlib only (exception). Demo `mix hex.audit`: no advisories.
- The run first rejected two new open issues, #131 and #132; both now have ledger items (below).

## Task 3: Nightly read for the actions group

The first scheduled Nightly on a SHA containing the actions-group squash (346754fe) is run 38868181351 on f5ae9442:
**red, not caused by the actions bump.** Causes:

- Compat Matrix (1.18, 27) / (1.18, 28): Elixir 1.18 type checker flags an unreachable clause in
  `test/support/strict_conn_adapter.ex` (added in #124) under `--warnings-as-errors`.
- Dialyzer (fresh PLT): the same clause plus one in `chunk/2`.
- Nightly Incident Lifecycle: created #131 and a duplicate #132 (issue list lag after create), then failed on the
  competing inventory.

Fix PR #133 removes the clauses and makes the incident replay wait for mutation visibility (harness reproduces the
duplicate against the old script; 36/36 with the fix). #131 is `retain` (lifecycle closes it on the next green
scheduled Nightly); #132 is `close` pending a maintainer close as duplicate before the next Nightly.

Every landing's twin gate is `not-applicable: twin not built (Phase 137)`, never a pass (jq check true, 7 landings).

## Checks

- Harnesses: collect_inbox 70/70, validate_inbox_ledger 72/72, dep_landing_evidence 58/58, nightly_incident 34/34
  (36/36 on the #133 branch).
- `mix test` dependabot/nightly/quality_signal/ci_lane_split/live_truth_parity policy tests: 80 tests, 0 failures.
- `automation_first_contract.sh`: exit 0.
- `repo_hygiene_check.sh`: exit 0 but `Result: not ready` with 2 local-only BLOCKs: the untracked
  `.planning/milestone.lock` (must never be committed) and the local `main` ref, which holds 21 unpushed pre-squash
  phase-133 commits (left untouched). No repo-state BLOCK.
