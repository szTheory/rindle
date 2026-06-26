---
phase: 106-trigger-split-matrix-lane-refinement
reviewed: 2026-06-22T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/nightly.yml
  - CONTRIBUTING.md
  - RUNNING.md
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 106: Code Review Report

**Reviewed:** 2026-06-22
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Phase-106 CI/CD trigger-split: the `ci.yml` rewrite (lean PR `package-consumer` +
push-only `package-consumer-full`; `gcs-soak`/`package-consumer-gcs-live` extracted), the new
`nightly.yml` (compat-matrix + gating Dialyzer + GCS soak lanes + summary/issue jobs), and the
`CONTRIBUTING.md`/`RUNNING.md` docs.

**The workflow YAML is correct and safe.** I verified the load-bearing invariants the milestone
calls out and they all hold:

- `name: CI` and the `ci.yml` filename are preserved (ci.yml:1), so `release.yml gate-ci-green`
  (`workflow_id: 'ci.yml'`, run-conclusion check) and `release-please-automerge.yml`
  (`on: workflow_run: workflows: [CI]`, `head_branch == 'main'`) remain coupled correctly.
- `nightly.yml` is a standalone file named `Nightly` with only `schedule`/`workflow_dispatch`
  triggers — invisible to all three release consumers and unable to become a PR required check.
- Job migration is exact: `gcs-soak` + `package-consumer-gcs-live` removed from `ci.yml` and
  present in `nightly.yml`; `package-consumer-full`, nightly `compat-matrix`, and nightly
  gating `dialyzer` added. No job was dropped or duplicated.
- Every `needs:` reference in both files resolves to a defined job (no dangling dependency).
- Both files parse as valid YAML.
- The nightly Dialyzer PLT key uses the **literal** `otp27-elixir1.17` segment (nightly.yml:188,208),
  correctly avoiding the empty-`${{ matrix.* }}` poisoned-key footgun its own comment warns about.
- Push:main-gated demo jobs (`cohort-demo-smoke`, `adoption-demo-e2e`) and `package-consumer-full`
  carry **no** `continue-on-error`, so a failure still drives the run conclusion non-success and
  blocks `gate-ci-green` — the release gate is preserved despite their removal from `CI Summary.needs`.
- **No security defects:** no untrusted `github.event.*` field is interpolated into any `run:`
  shell; all real secrets use `${{ secrets.* }}`; `minioadmin`/`dryrun-placeholder` are throwaway
  local/dry-run values, not credential exposure.

All findings below are **documentation accuracy** defects in `RUNNING.md`: the prose tables were
not fully updated to match the topology the same phase implemented. None block the workflows from
running correctly, but they misstate the merge/release gate to maintainers — the exact audience
`RUNNING.md` §"CI lane severity" exists to serve.

## Structural Findings (fallow)

No structural findings block was provided for this review.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: RUNNING.md still lists demo lanes as branch-protection required checks, but they are no longer even in the gate graph

**File:** `RUNNING.md:108-110`
**Issue:** The "Release train" section states: "Branch protection required checks ... include
Quality (both matrix cells), ... Adoption Demo E2E, Cohort Demo Smoke, and brandbook-tokens."
Two problems compound here:
(1) The actual required-check set is **only `CI Summary`** (`scripts/setup_branch_protection.sh`
`REQUIRED_CHECKS=("CI Summary")`). None of the individually-named jobs are required contexts —
they are gated transitively through `CI Summary.needs`. This was already loosely worded, but
(2) Phase 106 **removed** `cohort-demo-smoke` and `adoption-demo-e2e` from `ci-summary.needs`
(ci.yml:1282-1292; they were present in the pre-phase `ci-summary.needs`). So those two jobs are
now neither required checks nor in the `CI Summary` gate graph at all. A maintainer reading this
line would believe `Cohort Demo Smoke` / `Adoption Demo E2E` gate merges via branch protection;
they do not. (Their push:main run-conclusion still blocks *release* — but not the PR merge gate
this sentence describes.)
**Fix:** Correct the required-check list to reflect reality and the phase change, e.g.:
```text
Branch protection enforces a single required status check, `CI Summary`
(scripts/setup_branch_protection.sh). The merge-blocking PR lanes it transitively gates are
listed in CI Summary.needs (quality, optional-dependencies, integration, contract, proof,
package-consumer, adoption-demo-unit, adopter, brandbook-tokens, ci-script-tests). As of Phase
106, cohort-demo-smoke and adoption-demo-e2e run only on push:main and are NOT in CI Summary's
needs; their regressions are caught on main (and block release via the push:main run conclusion),
not on the PR.
```

### WR-02: `gcs-soak` / `package-consumer-gcs-live` "When it runs" column still says `needs: quality` after the move to nightly

**File:** `RUNNING.md:78-79`
**Issue:** Both rows' "When it runs" cell reads `` `needs: quality`; repo + secrets ``. After the
Phase-106 move, neither nightly job has a `needs:` clause — `gcs-soak` (nightly.yml:221-224) and
`package-consumer-gcs-live` (nightly.yml:292-295) run directly off the `schedule`/`workflow_dispatch`
trigger with only an `if: github.repository == ...` gate. The `needs: quality` claim is stale and
misleading (there is no `quality` job in `nightly.yml` to depend on).
**Fix:** Change the "When it runs" cell for both rows to reflect the nightly cadence, e.g.
`nightly (schedule 07:27 UTC) / workflow_dispatch; repo szTheory/rindle + secrets` and drop the
`needs: quality` text.

### WR-03: `package-consumer-gcs-live` row self-contradicts on `continue-on-error`

**File:** `RUNNING.md:79`
**Issue:** The Notes cell says both `` Job-level `continue-on-error`; live GCS install-smoke when
secrets present. `` **and** `Phase 106: moves to nightly.yml and drops continue-on-error so it
becomes a real nightly signal`. The first clause describes the pre-phase state and is now false:
`nightly.yml` has zero `continue-on-error` keys (verified across the whole file), so the job is
gating. A reader cannot tell from this row whether the lane currently masks failures or not.
**Fix:** Remove the stale leading clause so the cell states the post-move truth, e.g.:
`Live GCS install-smoke when secrets present (skipped otherwise). Phase 106: moved to nightly.yml
and GATING — continue-on-error dropped, so a live-GCS regression is real nightly red.`

### WR-04: `package-consumer` repo-hygiene gate is documented merge-blocking on PR but now runs only on push:main

**File:** `RUNNING.md:69`
**Issue:** Row `` | `package-consumer` — repo hygiene gate | merge-blocking | Same job | `` states
the `repo_hygiene_check.sh --ci` step is merge-blocking within the PR `package-consumer` job. After
the lean/full split, the repo-hygiene step exists **only** in `package-consumer-full`
(ci.yml:747-748), which is `if: github.event_name != 'pull_request'` — i.e. it never runs on a PR.
The lean PR `package-consumer` job (ci.yml:515-652) has no repo-hygiene step. So the hygiene gate
is no longer merge-blocking on PRs; it is a push:main/release gate. The doc overstates the PR-side
guarantee.
**Fix:** Either move the row under the `package-consumer-full` grouping with `When it runs =
push:main/release`, or relabel it: `package-consumer-full — repo hygiene gate | off-critical-path |
push:main/release | scripts/maintainer/repo_hygiene_check.sh --ci (no longer on the PR lane)`.

## Info

### IN-01: Lean PR `package-consumer` job display name advertises "Release Preflight" it no longer runs

**File:** `.github/workflows/ci.yml:516`
**Issue:** The lean PR job is named `Package Consumer Proof Matrix + Release Preflight`, but release
preflight (`scripts/release_preflight.sh`) moved to `package-consumer-full` (ci.yml:742-745). The
lean job runs only the `image` install-smoke + version-alignment. The name now overstates the lane.
Note the name is also load-bearing for the `ci-observability` jq prefix match
(`startswith("Package Consumer Proof Matrix")`, ci.yml:1246), so it cannot be changed casually.
**Fix:** Optional — if the name is renamed for honesty (e.g. `Package Consumer Image Smoke (PR)`),
update the `ci-observability` jq `startswith(...)` prefix in the same change. If left as-is for
check-name stability, add an inline comment noting the name is retained deliberately.

### IN-02: CONTRIBUTING.md "compatibility matrix (nightly)" omits the home-cell/PR-ceiling nuance documented elsewhere

**File:** `CONTRIBUTING.md:83`
**Issue:** "the broad OTP×Elixir compatibility matrix (nightly)" is accurate, but the nightly
`compat-matrix` deliberately re-runs the `1.17/27` PR home cell (nightly.yml:52-53) and the
`1.15/26` PR floor cell, overlapping the PR `quality` matrix. A contributor could read this as
"nightly covers versions PR does not," which is only partly true. Minor; the CONTRIBUTING framing
("breadth after merge") is otherwise correct.
**Fix:** Optional clarity tweak: "the broad OTP×Elixir compatibility diagonal (nightly; ~6 cells
including 1.15/25, 1.16/26, 1.18/27, 1.18/28 beyond the two PR cells)."

### IN-03: RUNNING.md adopter-facing "GitHub Actions" FFmpeg guidance recommends the action CI itself abandoned

**File:** `RUNNING.md:184-194`
**Issue:** The adopter FFmpeg matrix tells readers to use `FedericoCarboni/setup-ffmpeg@v3` with
`ffmpeg-version: 6.0`, while every CI/nightly FFmpeg step explicitly replaced that action because it
"intermittently failed ('Failed to get latest johnvansickle ffmpeg release') and blocked merges"
(ci.yml:95-99 and elsewhere; the repo now uses `scripts/ci/install_ffmpeg.sh`). This predates
Phase 106 (not introduced here), but it is an internal-consistency defect in the same file the
phase edited: the doc recommends to adopters the exact tool the maintainers found unreliable.
**Fix:** Point adopters at the same reliable install path CI uses (static johnvansickle via
`scripts/ci/install_ffmpeg.sh`, or apt where `>= 6.0` is available), or at minimum drop the
`@v3` recommendation. Out of strict Phase-106 scope, but worth a fast-follow.

---

_Reviewed: 2026-06-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
