---
id: SEED-261021-918
status: dormant
planted: 2026-10-21
planted_during: v1.26 Phase 136
trigger_when: "Required CI approaches a job timeout, PR feedback exceeds its measured envelope, or a milestone touches CI/CD, release engineering or contributor experience."
scope: Medium
---

# SEED-261021-918: Reduce the required CI critical path without weakening proof

## Why This Matters

PR #162 required Proof hit its unchanged 15-minute ceiling twice on frozen source 4fdd3fba. Attempt 2 spent 10m08s in the adoption proof matrix before its sequential Nightly harness stage was cancelled after another 3m24s. Both Quality cells, the package-consumer lane and the other required jobs passed. Slow or cancelled required checks block contribution and merging even when the underlying assertions are passing.

The older SEED-003 performance audit was consumed by v1.20; this is a new measured regression, not a reopening of that completed audit. Preserve its useful audit prompt and lessons.

## When to Surface

**Trigger:** recurring job timeouts, CI median/p95 over the accepted envelope, or new CI/release/DX work. This is a maintainer-observed need, not speculative feature demand.

## Scope Estimate

A focused infra slice: collect step-level critical-path timings, inspect the fresh package authority lifecycle and repeated replays, assess precise cache contracts and scheduling dependencies, then make small measured changes. Compare cold/warm PR duration, p95, runner minutes and failure rates. Preserve actual package/lifecycle proof, fork safety, exact-SHA release coupling and the sole CI Summary context. Do not trade missing assertions or wider timeouts for an apparent speedup.

## Breadcrumbs

- .github/workflows/ci.yml — Proof and its dependency on the Quality matrix.
- scripts/maintainer/check_adoption_proof_matrix.sh — derived and built-package authority gates.
- test/install_smoke/live_truth_parity_test.exs — fresh generated-image consumer plus authenticated lifecycle replays.
- scripts/ci/test_verify_nightly_run.sh and test_nightly_incident.sh — isolated shell fixture workloads.
- .planning/phases/136-measured-quality-and-ci-ratchets/136-PROOF-TIMEOUT.json — original immutable timeout evidence.
- GitHub workflow 39530200284, attempts 1 and 2; Proof jobs 118997121937 and 119259329101.
- .planning/seeds/SEED-003-ci-cd-performance-audit.md — consumed predecessor and audit rubric.

## Notes

The immediate low-risk candidate is parallel execution of the four independent Nightly harnesses, with executable overlap and failure-propagation tests. Track that small fix in Phase 136. Broader pipeline restructuring belongs to this seed. Capturing a seed does not close or waive active CI-16 timing acceptance.
