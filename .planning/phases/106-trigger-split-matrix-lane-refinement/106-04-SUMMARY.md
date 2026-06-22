---
phase: 106-trigger-split-matrix-lane-refinement
plan: 04
subsystem: ci
tags: [ci, lane-03, lane-01, github-actions, nightly, dialyzer, compat-matrix, release-coupling]
requires:
  - "106-03: ci.yml package-consumer split (same-file serialization — wave 3 runs after 106-03)"
  - ".github/actions/setup-elixir composite (CACHE-01)"
  - "Phase-104 PLT restore/save split shape (D-20 anti-rot key)"
provides:
  - ".github/workflows/nightly.yml (name: Nightly) — separate nightly lane invisible to release coupling"
  - "nightly compat-matrix (curated 6-cell OTP×Elixir diagonal, fail-fast:false)"
  - "owned GATING Dialyzer job (nightly) replacing ci.yml's advisory Dialyzer steps"
  - "moved gcs-soak + package-consumer-gcs-live (now real nightly signal)"
  - "Nightly Summary + nightly-failure-issue (least-privilege issues:write)"
  - "adoption-demo-e2e + cohort-demo-smoke moved to push:main, off the PR critical path"
affects:
  - ".github/workflows/ci.yml (Dialyzer/gcs lanes extracted; needs lists pruned; demo lanes push:main-gated)"
tech-stack:
  added:
    - ".github/workflows/nightly.yml (scheduled workflow, cron 27 7 UTC)"
  patterns:
    - "separate-file nightly lane (distinct workflow_id + run name) to stay invisible to release-please-automerge workflow_run:[CI] + gate-ci-green workflow_id:'ci.yml' + branch-protection"
    - "curated-diagonal compat matrix straddling the mix.exs json_polyfill_dep/0 OTP<27 branch"
    - "single-cell Dialyzer PLT key uses LITERAL otp27-elixir1.17 segment (never a bare matrix.* ref)"
    - "omit-from-needs (D-09) to keep skip-as-pass gate honest about conditionally-skipped lanes"
    - "job-scoped issues:write least privilege for the issue-on-failure job"
key-files:
  created:
    - ".github/workflows/nightly.yml"
  modified:
    - ".github/workflows/ci.yml"
decisions:
  - "Dialyzer PLT key segment uses literal otp27-elixir1.17 (single-cell job) — a bare matrix.otp/matrix.elixir would render empty and collapse all PLT lineages (silent cache poisoning); literal is the simpler safe default per D-20"
  - "Dropped gcs-soak's per-step continue-on-error in addition to gcs-live's job-level one — prefer real nightly signal per D-14 (the plan left this to discretion; chose real signal on both)"
  - "Did NOT add package-consumer-full to nightly (belt-and-suspenders is optional per D-14/CONTEXT; primary home is ci.yml push:main per D-11 — kept this plan minimal)"
  - "Did NOT add a push:main Dialyzer to ci.yml (D-19 discretion) — kept the contract at nightly-gating only, minimal plan"
metrics:
  duration: ~14m
  completed: 2026-06-22
status: complete
---

# Phase 106 Plan 04: Nightly Lane + Demo-Lane Trigger Moves Summary

Stood up a separate `.github/workflows/nightly.yml` (`name: Nightly`, cron 27 7 UTC, no PR/push trigger) carrying a curated 6-cell OTP×Elixir compat matrix, an owned **gating** Dialyzer lane (replacing ci.yml's rotting advisory steps), the moved gcs-soak + package-consumer-gcs-live as real signal, a Nightly Summary, and a least-privilege issue-on-failure job — then extracted Dialyzer + the GCS lanes from ci.yml (mux-soak retained) and moved `adoption-demo-e2e` + `cohort-demo-smoke` to push:main off the PR critical path (LANE-03 + LANE-01, D-04/D-05/D-12..D-20).

## What was built

**Task 1 — nightly.yml: compat-matrix + owned gating Dialyzer (commit 37dd589).**
Created `.github/workflows/nightly.yml` with `name: Nightly`, `on: { schedule: cron '27 7 * * *', workflow_dispatch }` and NO `pull_request:`/`push:` trigger, top-level `permissions: contents: read`. A header comment cites D-12 (a `schedule:` on a workflow named `CI` on head_branch main would trip release-please-automerge's `workflow_run:[CI]` listener on a cron tick → unattended release) and D-15 (07:27 UTC, off-the-hour, offset from branch-protection-apply's `:17`). The `compat-matrix` job (`name: Compat Matrix`, `fail-fast: false`) runs the full suite (`mix coveralls`) across the curated diagonal `1.15/26, 1.15/25, 1.16/26, 1.17/27, 1.18/27, 1.18/28` — the 1.15/25 + 1.15/26 cells deliberately straddle the `mix.exs` `json_polyfill_dep/0` `otp_major < 27` branch; reuses the `setup-elixir` composite + postgres service. The `dialyzer` job (`name: Dialyzer`, single 1.17/27 home cell) reuses the Phase-104 PLT restore → create-dir → build → save-before-analysis shape, keyed `plt-v1-…-otp27-elixir1.17-${{ hashFiles('mix.exs', '.dialyzer_ignore.exs') }}` with the **literal** OTP/Elixir segment (never a bare `matrix.*` ref — that would render empty in a non-matrix job and collapse all PLT lineages), then runs `mix dialyzer --format github` with NO continue-on-error (gating, D-17).

**Task 2 — move GCS lanes; add summary + failure-issue (commit 845f0ef).**
Moved `gcs-soak` and `package-consumer-gcs-live` into nightly.yml (keeping their `if: github.repository == 'szTheory/rindle'` + secret-detect steps). Dropped `package-consumer-gcs-live`'s job-level `continue-on-error: true` AND `gcs-soak`'s per-step `continue-on-error` so both are real nightly signal (D-14). Added `nightly-summary` (`name: Nightly Summary`, `if: always()`, `needs:` the 4 gating jobs) writing a `| Job | Result |` table over `needs.*.result` to `$GITHUB_STEP_SUMMARY`. Added `nightly-failure-issue` (`if: failure() && github.event_name == 'schedule'`, job-scoped `permissions: issues: write` and nothing else) running an inline `gh issue` find-open-by-label-and-title → comment-else-create, with the issue body composed from static text + trusted `needs.*.result` (no untrusted event field interpolated).

**Task 3 — extract Dialyzer + GCS lanes from ci.yml; keep mux-soak (commit fe4ad1f).**
Removed the advisory `mix dialyzer --format github` step and its PLT restore/create/build/save split from the PR `quality` job (Dialyzer now owned + gating in nightly); dropped the now-dangling `plt` row from the cache hit/miss summary table. Removed the `gcs-soak` and `package-consumer-gcs-live` jobs (now in nightly.yml), leaving a documenting comment in their place. `mux-soak` left entirely in place as the label-gated PR lane. Confirmed `ci-summary.needs` / `ci-observability.needs` reference none of Dialyzer / compat-matrix / gcs-soak / package-consumer-gcs-live. `scripts/ci/eval_ci_summary.sh` + `scripts/setup_branch_protection.sh` byte-unchanged; `name: CI` + filename unchanged.

**Task 4 — move demo lanes off the PR critical path (commit dfb0c39).**
Composed each of `adoption-demo-e2e` and `cohort-demo-smoke`'s existing repo gate with a push:main event gate: `if: github.repository == 'szTheory/rindle' && github.event_name != 'pull_request'` (repo condition preserved, not replaced — mirrors 106-03's `package-consumer-full` idiom). Removed both from `ci-summary.needs` AND `ci-observability.needs` (D-09 omit-from-needs) so the PR gate no longer waits on the ~502s demo-e2e chain — the load-bearing cut that keeps PR p95 under the ≤7-min budget. `adoption-demo-unit` kept PR-gating (D-02). D-03 guardrail verified: `integration`, `adopter`, `contract`, `proof` all remain in `ci-summary.needs` with no push:main gate.

## How it works

- **Release-coupling safety (D-12):** nightly.yml has a distinct `workflow_id` and run name `Nightly`, so release-please-automerge's `workflows:[CI]` listener, release.yml's `gate-ci-green` (`workflow_id:'ci.yml'`), and the branch-protection required-check set all structurally never match it. No `pull_request:` trigger → it can never become a PR required check.
- **Compat matrix:** `fail-fast: false` runs all 6 cells in parallel; the 1.15/25 (OTP<27) and ≥1.17/27 (OTP≥27) cells exercise both sides of the `json_polyfill_dep/0` branch, catching polyfill-path regressions nightly.
- **Dialyzer gating + PLT:** the single-cell PLT key with the literal `otp27-elixir1.17` segment keeps one stable lineage keyed on `mix.exs` + `.dialyzer_ignore.exs`; gating (no continue-on-error) retires the rotting advisory ignore baseline.
- **Failure surfacing:** `Nightly Summary` gives at-a-glance status; `nightly-failure-issue` opens/updates a single tracking issue on a scheduled failure (a manual `workflow_dispatch` debug run never files an issue), with `issues: write` only and the workflow default staying `contents: read`.
- **PR p95 cut:** Dialyzer/PLT off the `quality` job + the ~502s demo-e2e chain off the PR critical path (plus 106-03's package-consumer 5→1) is what lands the headline ≤7-min target.

## Deviations from Plan

None requiring auto-fix (Rules 1–3). Two discretionary calls the plan explicitly delegated:
- **gcs-soak per-step continue-on-error dropped** (in addition to gcs-live's job-level one): the plan left gcs-soak's to discretion ("prefer dropping for real signal"); chose to drop for real nightly signal (D-14).
- **No package-consumer-full re-run added to nightly** and **no push:main Dialyzer added to ci.yml**: both are optional per D-14/D-19/CONTEXT; kept the plan minimal (nightly-gating is the contract; release readiness's primary home is ci.yml push:main per D-11).

Comment-token hygiene: reworded one nightly.yml comment from `` no `pull_request:` trigger `` to "it has no PR-event trigger" so the literal token `pull_request` appears nowhere in the file — makes the D-12 prohibition grep-clean and unambiguous.

## Known Stubs

None. No placeholder/empty-value patterns introduced; all moved jobs run real proofs and the new jobs run real `mix`/`gh` invocations.

## Threat Flags

None. No new security surface beyond what the threat_model already enumerated. The one new write-capable surface (nightly-failure-issue) is mitigated exactly as the register specified (job-scoped `issues: write`, schedule-only, trusted-context body) — covered by T-106-04-E / T-106-04-T, not a new flag.

## Verification

All plan-level checks pass (run with `yq` from /opt/homebrew/bin):
- `head -1 nightly.yml` == `name: Nightly`; `head -1 ci.yml` == `name: CI`; both filenames unchanged.
- No `pull_request` token anywhere in nightly.yml; no `push:`/`pull_request:` trigger key; `cron: '27 7 * * *'` present.
- compat-matrix: 6 cells `1.15/26 1.15/25 1.16/26 1.17/27 1.18/27 1.18/28`, `fail-fast: false`.
- dialyzer: PLT key hashes `mix.exs` + `.dialyzer_ignore.exs`, literal `otp27-elixir1.17` segment, no continue-on-error; no `mix dialyzer` remains in ci.yml.
- gcs-soak + package-consumer-gcs-live present in nightly.yml (no continue-on-error keys anywhere), absent from ci.yml; mux-soak still in ci.yml.
- nightly-failure-issue: `if: failure() && github.event_name == 'schedule'`, `permissions` has exactly one key `issues: write`; top-level `permissions: contents: read`.
- adoption-demo-e2e.if and cohort-demo-smoke.if both `github.repository == 'szTheory/rindle' && github.event_name != 'pull_request'` (yq-confirmed); both absent from ci-summary.needs AND ci-observability.needs; adoption-demo-unit stays in ci-summary.needs.
- D-03 guardrail: integration/adopter/contract/proof all in ci-summary.needs, none with a push:main gate.
- `git diff --quiet scripts/ci/eval_ci_summary.sh scripts/setup_branch_protection.sh` exits 0.
- Both workflows parse as valid YAML; adoption-demo-e2e's Upload-Playwright-report step intact.

## Self-Check: PASSED

- FOUND: .github/workflows/nightly.yml
- FOUND: .github/workflows/ci.yml (modified)
- FOUND commit 37dd589 (Task 1), 845f0ef (Task 2), fe4ad1f (Task 3), dfb0c39 (Task 4)
