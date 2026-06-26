# Phase 106: Trigger Split + Matrix/Lane Refinement - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-22
**Phase:** 106-trigger-split-matrix-lane-refinement
**Areas discussed:** PR-lane signal cut, Nightly lane home, Package-consumer split, Dialyzer ownership

The maintainer selected all four gray areas and directed a deep multi-lens research pass
(four parallel `gsd-advisor-researcher` agents — GHA ecosystem best-practice, szTheory sibling
prior art, Rindle-internal code + Phase-103 timing baseline, project CI DNA) to produce a single
coherent, one-shot locked recommendation set per the project's decide-by-default contract
("so I don't have to think"). No follow-up choices were escalated; the synthesis was locked.

---

## PR-lane signal cut (trust/speed tradeoff — LANE-01/04)

| Option | Description | Selected |
|--------|-------------|----------|
| Ecto model | Full matrix on every PR (pure-lib norm) | |
| Tokio model | Representative gate on PR; breadth post-merge/nightly | ✓ |
| Keep demo-e2e + cohort-smoke on PR | Preserve all per-PR signal | |

**User's choice:** Tokio model (D-01). Stays on PR: quality(2 cells), optional-dependencies,
integration, contract, proof, adopter, adoption-demo-unit, brandbook-tokens, image-only
package-consumer, CI Summary (~7.2 min p95). Moves to push:main: adoption-demo-e2e (318s p95
browser flake; proxied by adoption-demo-unit) + cohort-demo-smoke (Docker, fork-skipped today).
integration/adopter/contract/proof non-negotiable on PR. Concurrency: cancel-on-PR /
serialize-never-cancel on main+release.
**Notes:** Flagged the demo-lane move as the one genuinely impactful reduction in per-PR signal;
research (flake variance, fork-skip, ≤7-min budget) backed it firmly; locked with an explicit
LANE-04 CONTRIBUTING/PR label.

## Nightly lane home (LANE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `nightly.yml` | Distinct workflow, `name: Nightly` | ✓ |
| `schedule:` in `ci.yml` | Single file | |
| `workflow_call` reusable shared lanes | Max DRY | |

**User's choice:** Separate `nightly.yml` (D-12). Decisive: a scheduled `CI` run would fire
`release-please-automerge.yml`'s `workflow_run: workflows:[CI]` listener on a cron tick → could
auto-merge a release PR + dispatch `release.yml`. Carries curated 6-cell OTP×Elixir diagonal,
gcs-soak, gcs-live (drop continue-on-error), owned Dialyzer, summary + issue-on-failure;
cron `27 7 * * *`; mux-soak stays a label-gated PR lane.
**Notes:** `branch-protection-apply.yml` precedent; composites neutralize duplication; reusable
workflow rejected (only setup is shared).

## Package-consumer split (LANE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| (A) One job, event-gated steps | Buries full-vs-lean in step `if:`s | |
| (B) Two jobs (lean PR + full off-PR) | Legible checks list | partial |
| (C) Matrixify 5 profiles | Parallel legs | partial |
| Hybrid B+C | Two jobs + matrixified full lane | ✓ |

**User's choice:** Hybrid B+C (D-08), sigra-proven. CI Summary OMITS package-consumer-full from
`needs:` (Design 1) — zero change to the Phase-105 gate; release proof via push:main run
conclusion (D-09/D-11). Resolves the 105-deferred skip-normalization note: omit-from-needs, not
normalize-inside-gate. fail-fast:false, no continue-on-error.
**Notes:** rulestead conditional skip-normalization reserved as the escalation path for a future
path-filtered lane only.

## Dialyzer ownership (LANE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| A. Advisory-on-PR (relocate, continue-on-error) | Zero DX risk, but rots | |
| B. Gating-on-PR (rulestead/Oban) | Strong, but on critical path | |
| C. Owned-gating-nightly | Owned, off PR, enforced | ✓ |
| D. Nightly-advisory | Off PR but non-enforcing (rots) | |

**User's choice:** Option C (D-17). Dedicated gating `Dialyzer` job in nightly.yml; removed from
PR quality; NOT in CI Summary needs (D-18/D-19). PLT reuses Phase-104 split, keyed on
OTP+Elixir+hashFiles(mix.exs, .dialyzer_ignore.exs).
**Notes:** Advisory-anywhere rots the 11-entry ignore file; PR-gating violates the ≤7-min goal;
nightly-gating threads the needle (MTTD ~24h acceptable for a contract signal).

## Claude's Discretion

Concurrency `group:` key phrasing; nightly summary/issue body wording; exact matrix patch pins;
whether nightly also re-runs package-consumer-full for redundancy; optional paths:-filtered
profiles (lean Phase 107); skipping MinIO setup on the structural `gcs` leg.

## Deferred Ideas

GitHub merge-queue (`merge_group`); paths:-filtered install-smoke profiles; rulestead
conditional skip-normalization (escalation path); `workflow_call` reusable workflow; Phase 107
HARD-01..04 (incl. SHA-pinning the issue-on-failure action if a third-party one is chosen).
Reviewed-not-folded: 2026-06-19-fix-docker-demo-startup-warnings (weak 0.2 match, unrelated).
