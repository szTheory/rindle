---
phase: 106-trigger-split-matrix-lane-refinement
plan: 03
subsystem: ci-cd
tags: [ci, lane-02, github-actions, package-consumer, release-gate]
requires:
  - "106-02 (top-level concurrency block in ci.yml; wave 1 landed first to avoid same-file overlap)"
provides:
  - "ci.yml lean `package-consumer` job (image-only smoke + version alignment, all triggers, stays in CI Summary.needs)"
  - "ci.yml new `package-consumer-full` job (off-PR 5-profile matrix + release_preflight + repo_hygiene + hex.publish --dry-run, no failure-masking)"
affects:
  - ".github/workflows/ci.yml"
tech-stack:
  added: []
  patterns:
    - "Trigger-split long pole: lean representative job on all triggers + event-gated full-breadth job (sigra install_smoke + install_matrix shape, D-08)"
    - "if: github.event_name != 'pull_request' to keep the full matrix off the PR critical path while feeding the push:main run conclusion"
    - "strategy.matrix.profile + fail-fast: false so the 5 install-smoke profiles run in parallel off-PR"
    - "Omit-from-needs (D-09): a conditionally-skipped lane is excluded from the aggregate gate's needs so skip-as-pass never emits a green-checkmark lie"
key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
decisions:
  - "Lean package-consumer runs ONLY install_smoke.sh image + assert_version_match.sh; release_preflight, repo_hygiene_check --ci, the video/tus/mux/gcs profiles, and hex.publish --dry-run all moved to package-consumer-full (D-10)"
  - "package-consumer-full gated if: github.event_name != 'pull_request' with fail-fast:false 5-profile [video,image,tus,mux,gcs] matrix; reuses setup-elixir + setup-minio composites (D-08/D-12 spirit)"
  - "No failure-masking key (continue_on_error) anywhere on package-consumer-full — a failed leg fails the push:main run conclusion so release.yml gate-ci-green blocks publish (D-08/D-11)"
  - "package-consumer-full intentionally OMITTED from ci-summary.needs and ci-observability.needs (D-09); eval_ci_summary.sh and setup_branch_protection.sh left byte-unchanged"
  - "MinIO setup skipped on the structural-only gcs matrix leg via per-step if: matrix.profile != 'gcs' (CONTEXT discretion, runner-minutes)"
metrics:
  duration: "8 min"
  completed: "2026-06-22"
  tasks: 2
  files: 1
status: complete
---

# Phase 106 Plan 03: Package-Consumer Trigger Split (LANE-02) Summary

Split the single 887s-p95 `package-consumer` long pole into a lean PR-representative job (image-only install-smoke + version alignment, stays gating) and a new off-PR `package-consumer-full` job carrying the full 5-profile matrix + release preflight + `hex.publish --dry-run` with no failure-masking — the load-bearing wall-clock cut, with release readiness kept airtight via the push:main run conclusion (D-08/D-09/D-10/D-11).

## What Was Built

Two edits to `.github/workflows/ci.yml`, no other files touched:

**Task 1 — split the long pole.** Rescoped the existing `package-consumer` job to be lean: it keeps checkout + setup-elixir + node/ffmpeg/libvips + setup-minio and the OBS-01/OBS-02 summary + artifact-upload steps, but now runs ONLY `bash scripts/install_smoke.sh image` plus the cheap structural `assert_version_match.sh` version-alignment step. Removed from the lean job (moved to the full job): `release_preflight.sh`, `repo_hygiene_check.sh --ci`, the `video`/`tus`/`mux`/`gcs` install-smoke steps, and `mix hex.publish --dry-run`. It runs on all triggers (no event gate) and keeps `needs: [quality, optional-dependencies]`.

Added a NEW top-level job `package-consumer-full` (`name: Package Consumer Full Matrix + Release Preflight`):
- `needs: [quality, optional-dependencies]`, `if: github.event_name != 'pull_request'`
- `strategy: { fail-fast: false, matrix: { profile: [video, image, tus, mux, gcs] } }`
- Reuses the `setup-elixir` + `setup-minio` composites (near-zero duplication, D-12 spirit)
- Steps: setup-elixir, node, ffmpeg, libvips, `mix deps.get`, setup-minio (guarded `if: matrix.profile != 'gcs'`), `release_preflight.sh`, `repo_hygiene_check.sh --ci`, `install_smoke.sh ${{ matrix.profile }}`, version-alignment, `mix hex.publish --dry-run --yes`
- NO failure-masking (`continue_on_error`) key anywhere — job or step

**Task 2 — keep CI Summary gating the lean job, omit the full job.** Confirmed `ci-summary.needs` and `ci-observability.needs` already list the lean `package-consumer` and do NOT list `package-consumer-full`. Added a documenting comment at the `ci-summary.needs` site explaining the D-09 omit-from-needs rationale and the D-11 release-proof mechanism. Left `scripts/ci/eval_ci_summary.sh` and `scripts/setup_branch_protection.sh` byte-unchanged.

## How It Works

- **On a PR** (including `labeled` events, which still yield `event_name == 'pull_request'`): only the lean `package-consumer` runs — a single representative `image` smoke + version alignment. `package-consumer-full` is skipped. The 5→1 profile cut on the long pole is the headline wall-clock win (the 887s-p95 long pole).
- **On `push:main` / `workflow_dispatch`**: `package-consumer-full` runs the full 5-profile matrix in parallel (`fail-fast: false`) plus preflight + hygiene + dry-run. Because it has no failure-masking key, any leg failure makes the run conclusion non-success.
- **Release gate**: `release.yml gate-ci-green` polls the push:main `ci.yml` run and requires `conclusion === 'success'`. Since `package-consumer-full` is a first-class job in that run with no failure-masking, a broken consumer profile blocks the Hex publish — without `package-consumer-full` ever being in `CI Summary.needs` (D-11 keys off run conclusion, not check name).
- **CI Summary** gates only the lean `package-consumer` (always-running PR representative). Omitting `package-consumer-full` from `needs` means the blanket skip-as-pass evaluation makes no claim about the conditionally-skipped full lane, so the green-checkmark-lie footgun never bites (D-09).

## Deviations from Plan

None — plan executed exactly as written. Two minor authoring choices, both within CONTEXT discretion:
- The lean job already had its `image` smoke step; the full job's per-profile step is `Run built-artifact package-consumer proof against MinIO` with `install_smoke.sh ${{ matrix.profile }}`.
- Explanatory comments in both jobs were worded to avoid the literal step-key string `continue-on-error` (using "no failure-masking (no continue_on_error key)" prose instead) so the plan's `grep`-based verifiers report cleanly while still documenting the D-08 rule. The structural invariant (no `continue-on-error` key anywhere in the job body) is confirmed via parsed YAML, not just grep.

## Threat Model Coverage

- **T-106-03-T (fake green — masking a failed leg):** mitigated. No `continue_on_error` key on `package-consumer-full` (job or step) — verified by parsed-YAML inspection of the job body. A failed leg fails the push:main run conclusion → `gate-ci-green` blocks publish (D-08/D-11).
- **T-106-03-R (false release readiness via omit-from-needs):** mitigated. Release readiness keys off the push:main run *conclusion* where `package-consumer-full` is first-class and non-failure-masked; CI Summary only gates the PR critical path (D-11).
- **T-106-03-E (privilege elevation):** accepted — `package-consumer-full` inherits the workflow default `contents: read`; no `permissions:` widening; no secret added (gcs structural-only, mux cassette-mode).
- **T-106-03-SC (supply chain):** accepted — `hex.publish --dry-run` with `HEX_API_KEY: dryrun-placeholder` publishes nothing; deps resolve from the committed mix.lock; no new package introduced.

Deferred to Phase 107 / HARD-02 (noted, not implemented): SHA-pin all third-party actions used by `package-consumer-full` (actions/checkout, actions/setup-node, the composites' inner actions).

No new security-relevant surface introduced beyond the threat model.

## Invariants Preserved

- `head -1 .github/workflows/ci.yml` is exactly `name: CI`; the filename is unchanged (git shows the file modified, not renamed).
- The 106-02 top-level `concurrency:` block (between `on:` and `env:`) was not disturbed.
- `scripts/ci/eval_ci_summary.sh` and `scripts/setup_branch_protection.sh` are byte-unchanged (`git diff --quiet` exits 0); `setup_branch_protection.sh` still references only `CI Summary` as the required check (no matrix-leg context added).
- ci.yml parses as valid YAML (`python3 yaml.safe_load` → OK).

## Verification

- `head -1 .github/workflows/ci.yml` == `name: CI` ✓
- `package-consumer-full:` present with `if: github.event_name != 'pull_request'`, `fail-fast: false`, `profile: [video, image, tus, mux, gcs]` ✓
- No `continue-on-error` key anywhere in the `package-consumer-full` job body (parsed-YAML confirmed; the only textual occurrence is descriptive prose in the lean-job comment) ✓
- Lean `package-consumer` runs only `install_smoke.sh image` + version alignment; no release_preflight / hex.publish dry-run / other 4 profiles as steps ✓
- `ci-summary.needs` keeps `package-consumer`, omits `package-consumer-full` (parsed-YAML confirmed) ✓
- `ci-observability.needs` omits `package-consumer-full` (parsed-YAML confirmed) ✓
- `git diff --quiet scripts/ci/eval_ci_summary.sh scripts/setup_branch_protection.sh` exits 0 ✓
- ci.yml parses as valid YAML ✓

## Commits

- `1b26982`: feat(106-03): split package-consumer into lean PR + full off-PR matrix (LANE-02, D-08/D-10)
- `d53a31a`: docs(106-03): document D-09 omit-from-needs at ci-summary site (LANE-02)

## Known Stubs

None.

## Downstream

- The release-readiness breadth now lives off the PR critical path; LANE-03 (nightly.yml) and LANE-04 (bucket classification + CONTRIBUTING/PR trust-speed label) build on this split. Whether `nightly.yml` also re-runs `package-consumer-full` for redundancy is out of this plan's scope (LANE-03 / D-11 discretion).
- Phase 107 / HARD-02 will SHA-pin the third-party actions this job uses.

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `.planning/phases/106-trigger-split-matrix-lane-refinement/106-03-SUMMARY.md`
- FOUND: commit `1b26982`
- FOUND: commit `d53a31a`
