# Phase 71: CI Proof Honesty — Research

**Researched:** 2026-05-27
**Phase:** 71-ci-proof-honesty
**Requirements:** CI-01, CI-02

## Summary

Phase 71 is a documentation-and-honesty wedge over existing CI infrastructure. No new jobs, no new test suites, and no dependency changes. The work splits cleanly into (1) a maintainer-facing severity matrix in `RUNNING.md` and (2) surgical removal of `continue-on-error` from the two highest-signal consumer/adopter lanes plus explanatory comments at every remaining non-blocking lane.

Current repo state matches CONTEXT assumptions (verified 2026-05-27):

| Location | COE present? | Action |
|----------|--------------|--------|
| `quality` steps: Credo, Doctor, AV doctor, Coveralls, Dialyzer | Yes (step-level) | Keep; document as advisory |
| `contract` step: Run contract tests | Yes (step-level) | Keep; document as advisory |
| `package-consumer` job | Yes (job-level, line 298) | **Remove** (CI-02) |
| `adopter` steps: doctor + Run adopter tests | Yes (step-level, ~515, 522) | **Remove** (CI-02) |
| `adopter` job | No job-level COE | No change |
| `mux-soak` job | No COE | Document secret-gated soak |
| `gcs-soak` test step | Yes (step-level, ~751) | Keep; document |
| `package-consumer-gcs-live` job | Yes (job-level, ~757) | Keep; document |

## Key Findings

### F-01: RUNNING.md insertion point

Intro block ends at line 12 (`matrix both of those entrypoints link to.`). `## Verify The Runtime` starts at line 14. New `## CI lane severity` section goes between them per D-01. FFmpeg content below must remain untouched.

### F-02: Existing comment pattern

`mux-soak` (~580–590) and `gcs-soak` (~680–686) use multi-line `#` blocks before job definitions explaining fork secrets, label gating, and cleanup. Phase 71 comment blocks should mirror this style with the prefix `# Phase 71 (CI proof honesty):`.

### F-03: docs_parity_test.exs

Existing test `"running guide publishes the durable FFmpeg install matrix"` asserts FFmpeg snippets only. Adding a sibling test for CI severity matrix (`## CI lane severity`, `merge-blocking`, `advisory`, `secret-gated soak`) aligns with D-12 discretion and prevents doc drift without touching README.

### F-04: release.yml gate-ci-green

Lines 204–214 log `(BYPASSED)` when CI conclusion is not `success` or wait times out. Matrix must document this under Notes; no workflow change this phase.

### F-05: Branch protection is out of repo

Removing COE makes jobs fail the workflow when red, but GitHub branch protection required-check lists are settings-only. D-12 post-merge checklist is manual.

### F-06: Risk of immediate CI redness

After CI-02, any existing `package-consumer` or `adopter` failure will fail PR CI. This is intentional (proof honesty). No pre-flight fix scope in Phase 71 unless execution discovers broken lanes.

## Implementation Approach

**Wave 1 — Documentation (CI-01):** Add severity matrix to `RUNNING.md`; optional docs_parity assertion.

**Wave 2 — Workflow honesty (CI-02 + criterion 4):** Remove COE from `package-consumer` and `adopter` steps; update merge-blocking job headers; add Phase 71 comment blocks at every remaining non-blocking lane listed in CONTEXT D-08.

## Files to Modify

| File | Change |
|------|--------|
| `RUNNING.md` | New `## CI lane severity` section with table |
| `.github/workflows/ci.yml` | Remove 3 COE lines; add/update comment blocks |
| `test/install_smoke/docs_parity_test.exs` | Assert CI matrix section exists |

## Validation Architecture

Phase 71 verification is grep- and test-driven — no new ExUnit feature tests for CI YAML itself.

| Behavior | Verify method | Command |
|----------|---------------|---------|
| RUNNING.md matrix present | grep + docs_parity | `rg '## CI lane severity' RUNNING.md` |
| package-consumer COE removed | grep | `rg -n 'package-consumer:' -A3 .github/workflows/ci.yml` must not show job-level COE |
| adopter step COE removed | grep | `rg 'continue-on-error' .github/workflows/ci.yml` excludes adopter doctor/lifecycle steps |
| Phase 71 comments present | grep | `rg 'Phase 71 \\(CI proof honesty\\)' .github/workflows/ci.yml` |
| Docs parity | ExUnit | `mix test test/install_smoke/docs_parity_test.exs` |

Quick run: `mix test test/install_smoke/docs_parity_test.exs --only test`
Full suite not required for every task; run targeted grep + single test file per plan.

## Open Questions

None — CONTEXT decisions are locked from assumptions mode (2026-05-27).

## RESEARCH COMPLETE
