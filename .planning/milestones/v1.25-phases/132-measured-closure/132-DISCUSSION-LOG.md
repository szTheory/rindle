# Phase 132: Measured Closure - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-25
**Phase:** 132-measured-closure
**Mode:** assumptions
**Areas analyzed:** Required-gate topology, evidence-guided required-path correction, fresh comparable
timing receipt, preservation re-census

## Assumptions Presented

### Required-gate topology

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Preserve `CI Summary` as the sole required check and retain its current required-job set, including independent image packed-consumer and adoption smoke proof. | Confident | `.github/workflows/ci.yml`; `test/install_smoke/ci_lane_split_test.exs`; `scripts/ci/test_ci_summary_gate.sh`; `.planning/phases/131-signal-preserving-ci-velocity/131-IMPLEMENTATION-VERIFICATION.md` |

### Evidence-guided required-path correction

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Select one narrowly evidenced correction inside an existing required PR job or step from same-head native job and long-pole step timings; do not alter topology, add reruns, or activate deferred partitions or cache redesign. | Likely | `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md`; `.github/workflows/ci.yml`; `.planning/phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md` |

### Fresh comparable timing receipt

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Replace the failed measurement after correction with ten successful, non-cancelled, first-attempt PR runs of one immutable head, requiring median <=480 seconds and nearest-rank p95 <=600 seconds. | Confident | `.planning/REQUIREMENTS.md`; `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` |

### Preservation re-census

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Reconfirm COV-05 and SAFE-02 against the final correction with authoritative coverage, established preservation proof, relevant packed-consumer proof, and bounded drift review. | Confident | `.planning/REQUIREMENTS.md`; `.planning/phases/131-signal-preserving-ci-velocity/131-IMPLEMENTATION-VERIFICATION.md`; `scripts/maintainer/refactor_contract.sh` |

## Corrections Made

No corrections — all assumptions confirmed by the user.

## Methodology Applied

- **Repo-Truth Evidence Ladder:** The completed ten-run receipt is decisive evidence of a median
  failure; passing p95 and local verification cannot substitute for CI-14.
- **Research-First Recommendation:** No external research is needed before planning; existing native
  job and step timing is the primary evidence source.
- **Narrow-Then-Escalate:** Partitions, cache redesign, reruns, required-check changes, and proof
  removal remain unsupported escalation.
- **Durable Planning Memory:** The existing receipt, preservation verification, and CI Summary/release
  coupling remain explicit downstream constraints.
- **Diminishing-Returns Gate:** One measured correction followed by one fresh ten-run window is the
  justified next iteration; broader redesign requires new causal evidence.
