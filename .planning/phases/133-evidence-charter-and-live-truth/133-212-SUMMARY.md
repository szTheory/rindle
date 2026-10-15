---
phase: 133-evidence-charter-and-live-truth
plan: "212"
subsystem: ci-evidence
tags: [landing, pull-request, merge, rescope]
status: complete
halted: false
requirements-completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requires:
  - phase: 133-211
provides:
  - "PR #114 squash-merged to main as ecd4d5a091d9cf3a8f0cf686cf35df7f24e1c03a"
  - "Main CI green on the merge SHA, including the main-only lanes"
affects: [133-213]
actuals:
  tasks: 4
key-decisions:
  - "The retired upstream MinIO image and dl.min.io binaries broke every MinIO lane, main included. They were replaced in a separate PR (#115) so the landing PR carried no unrelated change."
  - "The merge used --squash with a conventional fix(133) subject, at the user's stated preference. The repository now allows squash merges only."
---

# Plan 212 Summary: land Phase 133 on main

## Result

PR [#114](https://github.com/szTheory/rindle/pull/114) merged to main. **No requirement credit:** all five requirements stay Pending until Plan 213 evaluates scheduled Nightly runs on main.

All values below were read with `gh`.

| Field | Value |
|---|---|
| PR | #114 |
| PR head SHA | `bf24e63e2111ba33a9849e3898515c23830d5c2c` |
| Merge (squash) SHA | `ecd4d5a091d9cf3a8f0cf686cf35df7f24e1c03a` |
| Merged at | 2026-10-15T01:42:40Z |
| On origin/main | yes (`git merge-base --is-ancestor`) |

**CI on the PR head.** Run 38663131131 concluded `success`. Every merge-blocking job passed: Quality (1.15, 26), Quality (1.17, 27, true), Integration, Proof, Package Consumer Proof Matrix + Release Preflight, Adopter and CI Summary. Contract, CI Script Tests, CI Observability, Adoption Demo E2E Smoke, Adoption Demo Unit, both ADMIN-06 cells and brandbook-tokens also passed. The main-only lanes were skipped, as they are on every PR.

**CI on main at the merge SHA.** Run 38667117452 concluded `success`. That includes the main-only lanes: Cohort Demo Smoke, Adoption Demo E2E, and all five Package Consumer Full Matrix profiles. Mux Soak was skipped because it is label-gated.

## Reds on the way, in order

1. **First red, run 38644184111.** Three causes:
   - **MinIO:** the `minio/minio` pull was denied, which hit Integration, Package Consumer, Adoption Demo and Proof.
   - **jq keyword:** the incident harness used `$label`, which the jq 1.6 on ubuntu-22.04 rejects as a reserved keyword.
   - **RUNNING.md:** it named a `.planning` path, which the docs-link gate forbids.
2. **Fixes on the landing branch, each failing first:**
   - **jq:** renamed `$label` to `$wanted_label`. The harness went from 14 failures to 34/34 passing on jq 1.6 in an Ubuntu 22.04 container.
   - **RUNNING.md:** reworded. The parity test now forbids `.planning` in RUNNING.md.
3. **MinIO, PR #115 (merged `110db1af`):** a digest-pinned `cgr.dev/chainguard/minio` image that also supplies `mc`. The PR also covers `ensure_minio.sh` and both compose files, and adds a lock test. Main was merged into the landing branch afterwards.
4. **Proof job, phx_new:** `mix phx.new` was not found on cold runners. Proof now runs `scripts/ci/ensure_phx_new.sh` before the adoption-matrix gate, and an ordering lock test enforces this.
5. **Proof job, Postgres:** the package lifecycle rebuild failed SCRAM authentication, because its scrubbed environment dropped `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD`. Those variables now pass through with the MinIO settings. The failure message now shows the tail of the output, which is where the error appears.

Each fix was also cherry-picked to `gsd/phase-133-execution`, and the closure check passed after each one.

## Follow-up: release train

Release-please PR #116 (0.4.7) failed Quality. The Phase 133 parity tests pinned `0.4.6`, and two active `.planning` docs named it as the current version.

The fix landed as PR #117 (squash commit `98c049be`). It included:
- The tests derive the version from `mix.exs`.
- The docs no longer pin the version, and the JTBD-MAP snapshot header is marked historical.
- A new test validates the active surfaces against a simulated patch bump. It was red first.

What happened next:
- Main CI on `98c049be`, run 38675125658, failed once in Package Consumer Full Matrix (video). The generated-app smoke exited 2 with no inner detail. A single `gh run rerun --failed` passed (attempt 2), so this is recorded as a flake.
- Release-please did not refresh #116, because `test:` commits do not change the changelog. It was rebased with `gh pr update-branch 116 --rebase`. CI went green and the repository's automerge merged it as `46e4dbc3`.
- release.yml passed: exact-SHA gate, Publish to Hex, Public Verify and the RELEASE-TRAIN baseline update. **Hex 0.4.7** is published and tagged `rindle-v0.4.7`, and the label moved to `autorelease: tagged`.

## Known debt

The debt carried over from 133-211 still applies: phase-133 `.planning` path coupling in the Nightly scripts, and the census test flake to watch.
