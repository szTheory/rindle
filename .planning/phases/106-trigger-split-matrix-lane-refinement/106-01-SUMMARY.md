---
phase: 106-trigger-split-matrix-lane-refinement
plan: 01
subsystem: ci-docs
status: complete
tags: [LANE-04, ci, docs, lane-classification, contributing, trust-speed]
requires:
  - .planning/phases/103-observability-baseline/103-BASELINE.md
  - .planning/phases/106-trigger-split-matrix-lane-refinement/106-CONTEXT.md
provides:
  - 106-LANE-CLASSIFICATION.md A–E test-value classification (LANE-04)
  - CONTRIBUTING.md trust/speed label (on-PR vs after-merge/nightly)
  - RUNNING.md lane-severity forward reference to the Phase-106 trigger split
affects:
  - .planning/phases/106-trigger-split-matrix-lane-refinement/106-02-PLAN.md
  - .planning/phases/106-trigger-split-matrix-lane-refinement/106-03-PLAN.md
  - .planning/phases/106-trigger-split-matrix-lane-refinement/106-04-PLAN.md
tech_stack:
  added: []
  patterns:
    - "Tokio model: representative gate on PR, breadth post-merge/nightly (D-01)"
    - "omit-from-needs (D-09): conditionally-skipped full lane is excluded from CI Summary.needs, not normalized inside the gate"
key_files:
  created:
    - .planning/phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md
    - CONTRIBUTING.md
  modified:
    - RUNNING.md
decisions:
  - "LANE-04 classification uses 5 buckets (keep/optimize/move-to-nightly/label-gated-PR-lane/off-critical-path); quarantine (D) and delete (E) buckets are empty — none identified, not invented."
  - "mux-soak is bucketed as a label-gated PR lane and stays in ci.yml — explicitly NOT move-to-nightly (D-14)."
  - "Coverage measurement is off the PR critical path as advisory telemetry; mix coveralls stays as the gating test invocation, no per-PR coverage-% gate (D-07)."
  - "CONTRIBUTING carries a copy-pasteable trust/speed block + a /gsd-ship-time PR-body paste handoff so the LANE-04 PR-side half is not lost (no automation added here)."
metrics:
  duration_min: 2
  tasks: 3
  files: 3
  completed: "2026-06-22"
---

# Phase 106 Plan 01: LANE-04 Classification, CONTRIBUTING Trust/Speed Label, RUNNING.md Forward-Reference Summary

LANE-04's documentation+label half: authored the A–E test-value classification doc that
backs every Phase-106 lane placement, created the repo's first `CONTRIBUTING.md` carrying
the copy-pasteable on-PR vs after-merge/nightly trust/speed label (≤7-min target), and
forward-referenced the trigger split in RUNNING.md's lane-severity section — all docs-only,
zero workflow YAML, zero `lib/` change, so it runs in parallel with the three YAML plans
(106-02/03/04).

## What was built

**Task 1 — `106-LANE-CLASSIFICATION.md` (commit `28ebf42`).** A 175-line A–E
classification placing every current `ci.yml` lane into exactly one of five buckets:

- **A (keep on PR):** `quality` (both cells), `optional-dependencies`, `integration`,
  `contract`, `proof`, `adopter`, `adoption-demo-unit`, `brandbook-tokens`, the scoped
  `image`-only `package-consumer`, `ci-summary` (+ non-gating `ci-observability` /
  `ci-script-tests`).
- **B (optimize):** matrixify the 5 install-smoke profiles into `package-consumer-full`;
  extract Dialyzer into an owned job.
- **C (move-to-nightly):** broad OTP×Elixir `compat-matrix`, `gcs-soak`,
  `package-consumer-gcs-live`, the owned gating Dialyzer lane.
- **Label-gated PR lane:** `mux-soak` ONLY — explicitly stated NOT nightly (D-14).
- **Off-critical-path:** `package-consumer-full` (push:main release proof),
  `adoption-demo-e2e`, `cohort-demo-smoke`, coverage measurement.
- **D (quarantine) & E (delete): EMPTY** — none identified, not invented.

Each entry carries a one-line rationale citing the governing decision id (D-01..D-20) and,
where relevant, the 103 baseline avg/p95 (e.g. the 550s avg / 887s p95 `package-consumer`
long pole). A coverage table proves every job is placed exactly once.

**Task 2 — `CONTRIBUTING.md` (commit `6dbb229`).** The repo's first CONTRIBUTING file,
with a "## CI: what runs on your PR vs after merge" section carrying the verbatim CONTEXT
trust/speed draft as a copy-pasteable block: the on-PR representative gate (≤7-min target,
incl. the representative `image` package-consumer smoke) and the after-merge/nightly
breadth (full 5-profile matrix + release preflight + `hex.publish --dry-run`, Playwright
E2E, Docker cold-start, compat matrix, owned Dialyzer, real-API GCS/Mux soak). States the
why (expensive / browser-or-Docker-flaky / live-third-party), the "caught within one merge,
blocks the next merge not the author" MTTD framing, and a forward pointer that the
`/gsd-ship`-time step MUST paste the trust/speed paragraph into the PR body (the LANE-04
PR-side half). Notes the deeper `mix ci` + local-command docs are Phase 107 (HARD-03).

**Task 3 — `RUNNING.md` lane-severity forward-reference (commit `3eaafc3`).** Added a note
block under `## Maintainer: CI lane severity` describing the Phase-106 split (lean
`image`-only `package-consumer` on PR + `package-consumer-full` on push:main/release; the
compat matrix / `gcs-soak` / `package-consumer-gcs-live` / owned gating Dialyzer move to a
separate `nightly.yml`; `mux-soak` stays as a label-gated PR lane). Updated only the
drifting cells (Dialyzer row, package-consumer rows split into lean + `-full`,
`gcs-soak` / `package-consumer-gcs-live` / `mux-soak` rows); cross-linked
`106-LANE-CLASSIFICATION.md`. Left the merge-blocking PR lanes (`quality`, `integration`,
`contract`, `proof`, `adopter`) unchanged in severity and reasserted the `name: CI` /
`ci.yml` filename invariant (no rename claimed).

## Deviations from Plan

None — plan executed exactly as written. All three tasks are `type="auto"`; no Rule 1–4
deviations, no authentication gates, no package installs (docs-only, supply-chain threat
T-106-01-SC accepted).

## Verification

- `test -f CONTRIBUTING.md` ✓ and `test -f .../106-LANE-CLASSIFICATION.md` ✓
- `git diff --name-only HEAD~3 HEAD` → exactly the three doc files; **no
  `.github/workflows/*` touched** (verified — prohibition held), no `lib/` change, no
  `mix.lock`/`package-lock` churn.
- `grep -i 'label-gated' 106-LANE-CLASSIFICATION.md` resolves to the `mux-soak` entry ✓
- All required decision ids cited (D-01, D-04, D-05, D-08, D-10, D-13, D-14, D-17) ✓
- CONTRIBUTING contains "after merge" (artifact `contains:` requirement) + ≤7-min target +
  `image` smoke ✓
- RUNNING.md mentions the split, `package-consumer-full`, `nightly.yml`; mux-soak still a
  label-gated PR lane; `name: CI` invariant intact ✓

## Threat surface

No new security-relevant surface introduced (docs-only). The plan's threat register
(T-106-01-I info-disclosure accept, T-106-01-T classification-drift mitigate via plans
02/03/04 implementing exactly what this doc classifies, T-106-01-SC supply-chain accept)
holds. CONTRIBUTING.md / RUNNING.md / `.planning/` docs are repo-internal and must NOT
enter the Hex `files:` allowlist (boundary noted in the doc headers).

## Known Stubs

None. All three artifacts are complete, self-contained documentation.

## Notes for downstream plans (106-02/03/04)

- 106-02 implements Buckets A/B: lean `image`-only `package-consumer` on PR +
  `package-consumer-full` (`if: github.event_name != 'pull_request'`, `fail-fast: false`,
  no `continue-on-error`), OMITTED from `CI Summary.needs` (D-09); PR-lane `concurrency`
  cancel-in-progress, push:main/release serialize.
- 106-03 implements Bucket C: new `nightly.yml` (`name: Nightly`), curated ~6-cell
  diagonal `compat-matrix`, moved `gcs-soak` + `package-consumer-gcs-live` (drop
  `continue-on-error`), Nightly Summary + issue-on-failure.
- 106-04 implements Bucket B→C Dialyzer ownership (extract from `quality` → owned gating
  `Dialyzer` in nightly; NOT in `CI Summary.needs`) and final RUNNING.md / lane-severity
  reconciliation. `mux-soak` stays in `ci.yml` (do not move).

## Self-Check: PASSED

All created files exist on disk (`106-LANE-CLASSIFICATION.md`, `CONTRIBUTING.md`,
`106-01-SUMMARY.md`) and all three task commits are in git history (`28ebf42`, `6dbb229`,
`3eaafc3`).
