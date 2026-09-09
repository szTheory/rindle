# Phase 133: Evidence Charter and Live Truth - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `133-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-09-09
**Phase:** 133-evidence-charter-and-live-truth
**Mode:** assumptions
**Areas analyzed:** Evidence census authority, supported Nightly Dialyzer evidence, Nightly verdict and
incident lifecycle, release/support/adoption truth

## Assumptions Presented

### Evidence Census Authority

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Establish a versioned, machine-validated census bound to exact Git SHA, toolchain/configuration, and a finite taxonomy; normalize every candidate into exactly one `fix`, `retain`, or trigger-bound `defer`. | Likely | `.planning/ROADMAP.md`; `.planning/REQUIREMENTS.md`; `.planning/research/SUMMARY.md`; `.planning/milestones/v1.25-phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md` |

### Supported Nightly Dialyzer Evidence

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep the single Elixir 1.17 / OTP 27 Nightly cell as authority and require independent cold/fresh and restored-PLT proof without widening suppression identities. | Confident | `.github/workflows/nightly.yml`; `.dialyzer_ignore.exs`; `RUNNING.md`; `.planning/research/PITFALLS.md` |

### Nightly Verdict and Incident Lifecycle

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Add explicit per-job applicability and a fail-closed Nightly aggregate where failure, cancellation, missing/unexpected state, and impermissible skips are non-green. | Likely | `.github/workflows/nightly.yml`; `scripts/ci/eval_ci_summary.sh`; `scripts/ci/test_ci_summary_gate.sh`; GitHub Actions `needs` and status-function documentation |
| Maintain one rolling incident: scheduled failures open/update with exact-run evidence and only a later qualifying scheduled current-main recovery closes it; manual dispatch cannot mutate it. | Confident | `.github/workflows/nightly.yml`; `.planning/INBOX-TRIAGE.md`; live issue #88; GitHub Actions event/status documentation |

### Release, Support, and Adoption Truth

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Derive version from release authorities, lane semantics from parsed workflow topology, and package claims from built/unpacked consumer evidence rather than literal string presence. | Confident | `mix.exs`; `.release-please-manifest.json`; `.github/workflows/ci.yml`; `RUNNING.md`; `examples/adoption_demo/docs/adoption-proof-matrix.md`; `scripts/maintainer/check_adoption_proof_matrix.sh`; `test/install_smoke/generated_app_smoke_test.exs` |
| Repair active/live truth surfaces while preserving archived milestones and marked historical release receipts. | Confident | `.planning/milestones/v1.24-phases/122-live-truth-compile-clarity/122-RESEARCH.md`; `test/install_smoke/release_docs_parity_test.exs` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- Scheduled Nightly #94 through #101 all failed on immutable SHA
  `45ebde5e1bb851eb6e8a943ef68c52a714684661`; #90 through #93 were green on the same SHA before the
  repeated failures began. Latest inspected run: <https://github.com/szTheory/rindle/actions/runs/34324448817>.
- Public job metadata proves #94 through #101 used the restored-cache path: `Restore PLT cache` succeeded
  while the cache-miss-only create/build/save steps were skipped, then Dialyzer failed. Public metadata
  does not expose the actual warning or PLT contents.
- Full job logs require authenticated read-only GitHub Actions access. Phase 133 must collect and preserve
  the cache restore output and Dialyzer failure section before mutation without inferring corruption from
  the exit code alone.
- Issue #88 is the single live `nightly-failure` incident and contains exact-run-bound updates, but the
  current workflow has no recovery-close path; four later scheduled greens did not close it.
- GitHub documents `needs.<job_id>.result` as exactly `success`, `failure`, `cancelled`, or `skipped`.
  `failure()` does not cover cancellation or skipped-only outcomes; a dependent scheduled lifecycle job
  must use an `always()`-compatible predicate and inspect exact results.

