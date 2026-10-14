---
phase: 133-evidence-charter-and-live-truth
plan: "107"
subsystem: evidence
tags: [authority, authorization, tamper-rejection, reconciliation, tdd]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Plan 106 source-bound runtime and exclusive supply publication contracts
provides:
  - Diagnostic-only local halt results with no authoritative attempt-consumption lock
  - Literal Plan 111 decision, authorization, and private-candidate production gates
  - Forged-report, checkpoint, upstream-digest, and candidate mutation regressions
affects: [phase-133-local-qualification, phase-133-authorization, phase-133-terminal-proof]
actuals:
  tokens: 15878
  tasks: 2
  commits: 3
  plan_head_before: 044795ef0e85af3ced8e515915c6552013572be1
  plan_head_after: 02abfbe4f809f24d21277a99ef38d2e9d719c1ad
tech-stack:
  added: []
  patterns:
    - Separate unkeyed report consistency from execution authority
    - Bind editable decisions to independently supplied checkpoint context
    - Revalidate current authority bytes before invoking trusted read-only dependencies
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-107-TDD-RED-EVIDENCE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-107-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/verify_phase_133_105_outcome.mjs
    - scripts/maintainer/test_phase_133_105_outcome.mjs
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
    - .planning/phases/133-evidence-charter-and-live-truth/deferred-items.md
    - .planning/WINDOWS.md
key-decisions:
  - Local halted reports retain first-red diagnostics but cannot authenticate execution, consume a SHA, or close a requirement.
  - The checkpoint-handling caller must supply the literal answer and displayed preflight digest independently of DECISION.json.
  - Candidate acceptance requires the existing live verify-receipt path after all local bindings pass; this plan performs no remote qualification.
  - Historical fixture failures remain open and do not authorize changing immutable evidence.
patterns-established:
  - Test dependency injection is unavailable through the production CLI.
  - An inherited library-loading environment flag cannot suppress explicit CLI verification.
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification_credit: 0
coverage:
  - id: D1
    description: Fully rehashed halted reports pass consistency but fail execution authority; complete green reports remain candidates only.
    verification:
      - kind: integration
        ref: node scripts/maintainer/test_phase_133_105_outcome.mjs
        status: pass
      - kind: integration
        ref: test/install_smoke/phase_133_reconciliation_test.exs#fully forged and rehashed child execution fails production authority after consistency passes
        status: pass
    human_judgment: false
  - id: D2
    description: Plan 111 contracts reject mismatched checkpoints, current authority bytes, source identity, stops, and unverified candidates.
    verification:
      - kind: integration
        ref: "ERL_FLAGS='+S 4:4' ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only plan107 --seed 0"
        status: pass
    human_judgment: false
duration: 52 min
completed: 2026-10-07
status: complete
---

# Phase 133 Plan 107: Diagnostic Halt and Literal Authorization Summary

**Editable local halts now carry diagnostic-only authority; Plan 111 gates bind checkpoint context, exact source/ref, current upstream bytes, and live private-receipt verification.**

## Performance

- **Duration:** 52 min
- **Started:** 2026-10-07T18:23:37Z
- **Completed:** 2026-10-07T19:15:40Z
- **Tasks:** 2/2
- **Files changed:** 9 including this summary
- **Actuals:** realized pre-summary diff characters divided by four, rounded up; three task commits measured from the persisted plan ledger. The separate summary commit is outside that measurement interval.

## Accomplishments

- A fixture forges child starts/exits and recomputes every report, outcome, summary, and validation digest. Consistency still passes; production authority rejects the halt. Missing preflight publication also fails. Historical Plan 105 bytes remain unchanged.
- Halted supply/outcome verification returns `diagnostic_only`, retains first-red information, grants zero credit, and does not consume a source SHA. Explicit barred-source restrictions and exclusive publication remain in force. Green reports yield only `local_candidate` status before independent proof.
- Added read-only `--expect-plan111-decision`, `--expect-plan111-authorization`, and `--expect-plan111-candidate` modes. Copied-tree regressions cover source SHA/tree/ref, preflight digest, every upstream digest, stop behavior, missing/forged checkpoint context, red gates, review/security bindings, candidate run/attempt, incident nonmutation, and failed live verification.

## Task Commits

1. **Task 1 RED: forged local halt authority** — `808ac1ae` (`test`).
2. **Task 1 GREEN: diagnostic-only halt contract** — `14e4ef67` (`feat`).
3. **Task 2: literal authorization and private candidate proof** — `02abfbe4` (`feat`).

**Plan metadata:** committed separately after these task commits. Normal hooks were enabled for every commit; no tracked files were deleted.

## Verification

| Check | Result |
| --- | --- |
| `node scripts/maintainer/test_phase_133_105_outcome.mjs` | PASS, 3 tests |
| `node --test scripts/maintainer/phase_133_local_supply.test.mjs` | PASS, existing supply harness |
| Supported-cell reconciliation with `--only plan107 --seed 0` | PASS, 14 selected tests; 97 discovered, 83 excluded |
| Supported-cell full reconciliation with `--seed 0` | FAIL, 95 tests, 9 historical Plan 64/79 fixture failures; see below |
| Supported-cell `mix refactor_contract` | PASS, 97 tests and no cycles |
| `mix format --check-formatted` for both edited Elixir files | PASS |
| Node syntax checks for the edited production modules | PASS |
| `./scripts/maintainer/automation_first_contract.sh` | PASS |
| `git diff --check` | PASS |
| GSD RED evidence classifier and branch-local evaluation scope | PASS: `RED_EVIDENCE_OK`; all three task commits resolved |

The exact final focused command was:

```sh
ERL_FLAGS='+S 4:4' ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only plan107 --seed 0
```

The full run used the same command without `--only plan107`. It completed before the final two narrow parsing/CLI regressions were added; the final focused run covers all 14 Plan 107 tests on the committed implementation. No claim is made that the full reconciliation suite is green. Early runs overlapping implementation edits were discarded.

## TDD Gate Compliance and WR-01

- **RED:** `node --test --test-reporter=tap scripts/maintainer/test_phase_133_105_outcome.mjs` ran the named forged-halt test and failed its planned assertion: expected `diagnostic_only`, received no authority classification. This was an assertion failure after successful consistency checks, not a setup, discovery, or syntax failure.
- **Evidence:** `133-107-TDD-RED-EVIDENCE.json` preserves the actual TAP report, command, exit code, target, expected/actual values, and semantic assessment. The machine classifier returned `RED_EVIDENCE_OK` before GREEN and again during close-out.
- **GREEN:** the outcome verifier and reconciler distinguish diagnostic halts from green candidates; the forged fixture now passes the rejection regression. The tracer checks were rerun after its implementation commit.
- **REFACTOR:** no separate refactor was required.
- **WR-01 disposition:** the executable forged-halt acceptance defect is closed by this contract. This is not Phase 133 qualification or requirement closure; Plan 110 must bind the current executable result into its fresh authority record.

## Plan 108–111 Integration Contract

The production CLI exposes no dependency-injection or fixture bypass. The in-process tests substitute the external dependency boundary; they do not claim actual supply, census, or GitHub evidence for their synthetic source. Real authorization invokes source/tree verification, the production supply checker, and both production census checks. Candidate verification additionally invokes the existing trusted `verify_nightly_run.sh verify-receipt` command. No dispatch or remote write was executed here.

For a ready decision, the checkpoint-handling caller must supply:

```text
--checkpoint-answer authorize|stop
--checkpoint-preflight-sha256 <the byte digest displayed at the checkpoint>
```

These values must come from the actual checkpoint context, never be reconstructed from the editable decision/preflight files. They are an explicit caller trust boundary, not a cryptographic signature or evidence of user intent by themselves. A stopped preflight may record `stop` without a human answer only when its nonempty first-red record and zero-command contract are preserved. Stop can validate in decision mode but never in authorization or candidate mode.

The fixture builder `write_ready!/1` specifies the JSON shape for the later producers:

- Preflight and decision use schema 1, plan `133-111`, full `source.sha`/`source.tree`, and `refs/heads/phase-133-evidence-<first twelve SHA characters>`. Both preserve `requirements_completed: []`, `qualification_credit: 0`, and `remote_commands: 0`. Decision binds the exact preflight bytes and every upstream digest.
- The complete authority map contains `supply_sha256`, `local_gates_sha256`, `census_sha256`, `census_a_sha256`, `census_b_sha256`, `review_sha256`, `security_sha256`, `inventory_sha256`, `validation_sha256`, and `authority_sha256`, each checked against its fixed current file.
- Plan 110 authority binds the same source/ref and the upstream map excluding its own digest. Its `checks` cover review, security, Nyquist, Dialyzer, Nightly summary, incident, and truth with passing exit/status, a nonempty command, positive test count, and the same source. WR-01 must be closed by executable contract, with zero blocking/high findings.
- Current sections are `## Plan 110 Current-Source Review`, `## Plan 110 Current-Source Security`, and `## Plan 110 Current-Source Nyquist`. Their source/gates/census bindings and section digests must agree. Duplicate fields fail; section metadata cannot override upstream digests. Inventory binds `audited_subject`, `binding.subject_sha`, tree/gates/census digests, a nonempty item list, and no unresolved high IDs.
- Candidate bytes retain the existing canonical receipt schema. The Plan 111 summary binds candidate, decision, and preflight byte digests; full SHA/tree/ref; run ID; attempt 1; complete status; and no completed requirements. Candidate census/live-truth subjects and census ledger digest must match the authorization. Live verification remains mandatory even when every local hash agrees.

Plan 108 owns the remaining preflight/local-qualified/census/authority/terminal modes and the Plan 108 runner integration before source freeze, as already specified in its plan. In particular, it must extend the supply green-gate verifier's historical Plan 105 identity to the new Plan 108 identity; this plan did not run that collector or freeze a subject.

## Files Created/Modified

- `phase_133_local_supply.mjs` — removes editable-history attempt-consumption claims and returns diagnostic halt authority.
- `verify_phase_133_105_outcome.mjs` — exposes diagnostic versus candidate authority and preserves first-red information.
- `test_phase_133_105_outcome.mjs` and RED evidence JSON — full recomputed forgery and missing-publication regression.
- `validate_phase_133_reconciliation.exs` — green-only entry and literal Plan 111 production modes.
- `phase_133_reconciliation_test.exs` — 14 focused contract tests, including CLI execution despite an inherited library flag.
- `deferred-items.md` and `WINDOWS.md` — record the unrelated full-suite blockers; WINDOWS entry 40 remains open.

## Decisions Made

No new receipt or unkeyed hash is treated as proof of child execution or checkpoint authorization. All five requirements remain pending. Canonical Nightly evidence, Plan 105 history, STATE.md, and ROADMAP.md are byte-identical to the dispatch base. No product-scope or shipped-feature claims changed, so PROJECT.md was not modified.

## Deviations from Plan

1. **[Rule 3 — Verification environment] Missing worktree dependency/build caches.** Reused existing local dependency and test-build bytes in this worktree, dereferencing links, to run the installed supported runtime. No package-manager install, dependency change, or main-checkout write occurred. These are ignored runtime files, not committed deliverables.
2. **[Scope boundary — Verification limitation] Historical full-suite failures.** The full reconciliation command ran but could not pass: three Plan 64 cases report historical review-prefix drift; six Plan 79 cases stop at missing/duplicate authority headings. Representative cases from both groups reproduced with the validator and test modules from dispatch base `044795ef0e85af3ced8e515915c6552013572be1`, using only copied launcher/resource-path adaptations. These pre-existing authority defects were not repaired or weakened. Recorded in the deferred log and WINDOWS entry 40 in `02abfbe4`.

**Total deviations:** two execution/verification adjustments; no unrelated production fixes or architectural changes. **Impact:** the new contracts pass, but full-suite green status and downstream qualification remain blocked by historical evidence repair.

## Issues Encountered

The broad suite has nine historical fixture failures described above. The final Plan 107 checks, supply harness, formatting, refactor contract, and automation-first check pass. Future qualification must not infer full-suite success from the focused result.

## User Setup Required

None. No credentials or external configuration were needed for this plan.

## Self-Check: PASSED

Both created artifacts exist; all three task commits are ancestors of this worktree HEAD and resolve through GSD's branch-local evaluation scope. The RED evidence classifier passes. Coverage classification reports two automatically covered contract deliverables with no schema errors. Automation-first and diff checks pass after summary creation. The immutable evidence, all five pending requirements, STATE.md, and ROADMAP.md remain unchanged. The nine historical full-suite failures remain explicitly open rather than being represented as passing evidence.

## Next Phase Readiness

Ready for Plan 133-108's remaining implementation and integration work. Resolve the historical reconciliation blockers before claiming complete green qualification or freezing its evidence source. No qualification, census collection, source freeze, remote ref creation, or Nightly dispatch was performed in Plan 107. D-01/D-04 retain full source identity; D-05–D-17 and all five Phase 133 requirements remain pending.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-07*
