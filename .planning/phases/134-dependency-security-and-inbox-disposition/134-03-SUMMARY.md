---
phase: 134-dependency-security-and-inbox-disposition
plan: 03
subsystem: infra
tags: [bash, jq, ledger, validator, advisories, ci-script-tests]
status: complete

requires:
  - phase: 134-01
    provides: collect_inbox.sh inventory (rindle-inbox-inventory-v1)
  - phase: 134-02
    provides: dep_landing_evidence.sh landing JSON and twin literal
provides:
  - "scripts/maintainer/validate_inbox_ledger.sh: INBOX-02 / SEC-09 / DEPS-01 ledger validator (--offline, --inventory, --print-collector-args)"
  - "scripts/ci/test_validate_inbox_ledger.sh: 72-check fixture harness, one red fixture per rule"
  - ".planning/INBOX-LEDGER.json: stable offline-valid seed (11 items, 20 open advisories)"
  - "ci-script-tests: four named steps for the three Phase 134 harnesses and the offline ledger check"
affects: [134-04, 134-05, 134-06]

actuals:
  tokens: 27000
  tasks: 3
  commits: 3
plan_head_before: 05aa65fc050b040585cf9e743c79cbad4c4e944d
plan_head_after: d9a927e85ab528811ab43b34b87c4afac7d14b84

tech-stack:
  added: []
  patterns:
    - "one jq program holds shape + live rules; reasons collected as REJECT: lines, never short-circuited"
    - "closed trigger vocabulary evaluated in jq (trigstate: fired | pending | unevaluable)"
    - "clock read only in live mode (INBOX_NOW_EPOCH); offline proven clock-free by a failing fake date"

key-files:
  created:
    - scripts/maintainer/validate_inbox_ledger.sh
    - scripts/ci/test_validate_inbox_ledger.sh
    - .planning/INBOX-LEDGER.json
  modified:
    - .planning/INBOX-TRIAGE.md
    - .github/workflows/ci.yml
    - test/install_smoke/nightly_policy_test.exs

key-decisions:
  - "A merge item with pending_action skips the mergeable and lock-delta checks (recorded, never credited); without it the PR must have CI Summary success, not be behind, and a delta inside group_packages"
  - "Trigger and exception dates fire/expire after the whole named day (now >= date + 86400)"
  - "Unevaluable triggers (no hex_latest entry or terminal lookup) reject live; --print-collector-args emits --include for terminal items and gh_issue_closed trigger numbers, --hex-package for hex_version_gte packages"
  - "Advisory identity is (id, scope): the same id in root and demo needs two records"
  - "Demo advisory reachability recorded as runtime for bandit/mint/decimal (the demo is an app whose prod deps include bandit and req); RESEARCH example showed dev-test-only for bandit, which the demo mix.exs contradicts"

requirements-completed: []
requirements-advanced: [INBOX-02, SEC-09, DEPS-01]

coverage:
  - id: D1
    description: "Validator rejects every INBOX-02 rule (missing, duplicate, stale head/inventory, terminal, disposition fields, closed-vocabulary triggers, merge readiness, attribution)"
    requirement: INBOX-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_validate_inbox_ledger.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Advisory and source rules (SEC-09) and landing rules (DEPS-01, twin never pass) enforced; --offline reads no clock"
    requirement: SEC-09
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_validate_inbox_ledger.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Harnesses and offline ledger shape are merge-blocking steps in ci-script-tests without changing ci-summary.needs"
    requirement: DEPS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/nightly_policy_test.exs (+5 sibling policy tests)"
        status: pass
    human_judgment: false
---

# Phase 134 Plan 03: Ledger Validator Summary

**`validate_inbox_ledger.sh` turns disposition, advisory and landing accounting into a pass/fail predicate over a fresh inventory (72-check red-fixture harness), with a seeded offline-valid `.planning/INBOX-LEDGER.json` and merge-blocking `ci-script-tests` wiring.**

Duration: about 35 min. Tasks: 3. Files: 3 created, 3 modified. No ledger seed is requirement credit (credit is Plan 06 closure).

## Accomplishments

- **Tasks 1 and 2 (217a61a6):** the validator was written complete in one pass, so the tracer and the remaining-rules tasks share one commit (deviation, process only). Every rule emits a distinct `REJECT:` line and all reasons are collected before exit. Harness: 72 checks (clean, missing, duplicate, repo mismatch, all-problems-in-one-run, stale head, stale and future inventory, not-open and terminal mismatch, supersede/defer/unknown disposition, vocabulary, fired date / hex_version_gte / gh_issue_closed / unevaluable triggers, merge readiness, pending_action rebase accepted, attribution, advisory missing / not resolved / expired / missing trigger / open / stale / ignored / fired exception, source rules, landing twin / gate / delta / sha, offline cases incl. a failing fake `date`, CLI usage, `--print-collector-args`, shell-injection-is-data).
- **Task 3 (41936557, d9a927e8):** ledger seeded from a fresh live read-only collector run (2026-10-15T18:14:24Z, main `ae08818a`), triage file reduced to a pointer, four ci-script-tests steps appended after the #120 step, `nightly_policy_test` asserts them.

## Ledger seed contents

Items (11): #42 issue retain (TEST-08, Phase 136); #95 close (pending_action close, muontrap semver-major ignore); #105 merge (group ecto,ecto_sql), #108 merge (req), #109 merge (ex_aws), #112 merge (dev-dependencies: credo dialyxir earmark_parser erlex ex_doc ex_machina lazy_html makeup mox), #113 merge (actions, no packages), all with current head_sha and pending_action rebase; #120 merge with terminal `{closed, merged true}`; historical terminals #88 issue close, #93 supersede successor #113, #98 close.

Advisories (20, all `open`): root 11 (cowlib x3 dev-test-only, mint x6 optional-dep, decimal runtime, lazy_html dev-test-only) and demo 9 (mint x6 runtime, decimal runtime, lazy_html dev-test-only, bandit EEF-CVE-2026-105659 runtime, fix_version null). Source: `dependabot_alerts` source_disabled with rationale (dependency graph does not parse mix.lock; enable action offered in Plan 06). Landings: empty.

Live dry run of the validator against the fresh inventory: the only rejections are the 20 `advisory open` lines; coverage, heads, terminals (#88, #93, #98, #120), sources and triggers all pass.

## Verification

- `validate_inbox_ledger.sh --offline` on the committed ledger: ok.
- Harnesses: collect_inbox 70/0, validate_inbox_ledger 72/0 (also `/bin/bash` 3.2 and `ubuntu:22.04` jq 1.6), dep_landing_evidence 58/0.
- ExUnit: nightly_policy, quality_signal_policy, ci_lane_split, ci_observability, live_truth_parity, evidence_census: 113 tests, 0 failures (1 excluded).
- Acceptance greps: no `eval` or GNU-date flag in the validator; no `.planning/phases/134` path in scripts, test, .github; the four ci.yml literals count 4; `ci-summary.needs` untouched.
- `./scripts/maintainer/automation_first_contract.sh`: exit 0.
- Precondition: PR #120 MERGED (ae08818a), ancestor of HEAD, verified before the ci.yml edit.

## Deviations from Plan

**1. [Rule 3 - Blocking] Branch guard**: same adaptation as 134-01/02 (protected-branch check kept, agent-* allow-list skipped on the orchestrator-assigned `gsd/phase-134`).

**2. [Process] Tasks 1 and 2 committed together**: the validator and harness were built whole; splitting would have required artificially removing rules.

**3. [Rule 1 - Accuracy] Demo bandit reachability**: recorded `runtime` (demo `mix.exs` has bandit unconditionally) instead of the RESEARCH example `dev-test-only`; Plan 06's exception rationale should say demo-only/not shipped.

**4. [Rule 2 - Missing] Not implemented**: RESEARCH rule 5 tail ("every id in mix.exs `ignore_advisories` needs an exception and vice versa") is not checked; the collector clears ignores and mix.exs uses none, and the plan's behavior list omits it.

## Notes for downstream plans (04, 05, 06)

- Live run: `collect_inbox.sh --out inv.json $(validate_inbox_ledger.sh --print-collector-args --ledger .planning/INBOX-LEDGER.json)` (flag/value on separate lines; use `xargs`), then `validate_inbox_ledger.sh --ledger .planning/INBOX-LEDGER.json --inventory inv.json`.
- When a PR lands: change its item to `terminal {closed, merged true, state_reason null}`, drop `head_sha`/`pending_action`, append a `landings[]` record from `dep_landing_evidence.sh` (gates pass, twin literal, baseline_run_id required positive integer), flip its advisories to `resolved` only once absent from the inventory.
- Remaining PR heads change on rebase; update `head_sha` from a fresh inventory before live validation (a stale head is a `REJECT: stale`).
- Nothing blocks 134-04.

## Known Stubs

None.

## Threat Flags

None. Validator evaluates ledger text only as jq data (injection test in harness); no new endpoint or auth path.

## Self-Check: PASSED

- validate_inbox_ledger.sh, test_validate_inbox_ledger.sh, INBOX-LEDGER.json exist.
- Commits 217a61a6, 41936557, d9a927e8 are ancestors of HEAD.
