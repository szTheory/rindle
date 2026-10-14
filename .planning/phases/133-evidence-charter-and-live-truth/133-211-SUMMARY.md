---
phase: 133-evidence-charter-and-live-truth
plan: "211"
subsystem: ci-evidence
tags: [landing-branch, nightly, incident-genesis, edge-rows, rescope]
status: complete
halted: false
requirements-completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 0
requires:
  - phase: 133-210
  - decision: 133-RESCOPE (D-133-R4, R5, R7)
provides:
  - "Local branch phase-133-landing (from origin/main 45ebde5e; not pushed) carrying the 32 manifest files plus the full .planning tree"
  - "scripts/maintainer/check_phase_133_landing_closure.sh with --self-test (7 cases)"
  - "verify_nightly_run.sh verify-scheduled: read-only scheduled-run receipt with job conclusions and verdict artifact"
  - "manage_nightly_incident.sh genesis rule: verdict-log genesis cursor and adoption of the single labelled legacy incident (#88)"
  - "133-EDGES.md: all eleven edge rows mapped to passing named tests"
  - "Nightly evidence harnesses wired into the merge-blocking Proof job"
affects: [133-212, 133-213]
actuals:
  tasks: 4
  commits: 12
key-files:
  created:
    - scripts/maintainer/check_phase_133_landing_closure.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-LANDING-MANIFEST.txt
    - .planning/phases/133-evidence-charter-and-live-truth/133-EDGES.md
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
    - scripts/ci/manage_nightly_incident.sh
    - scripts/ci/test_nightly_incident.sh
    - .github/workflows/ci.yml
    - test/install_smoke/evidence_census_test.exs
    - test/install_smoke/live_truth_parity_test.exs
    - test/install_smoke/ci_cache_hygiene_test.exs
key-decisions:
  - "Genesis = the earliest verdict artifact (retained or expired, else the current attempt) when no checkpoint exists. Runs before it are pre-genesis legacy. Unlabelled open incidents and mutation markers older than genesis fail closed."
  - "verify-scheduled needs --run-id when several scheduled runs share the SHA (main often sits on one SHA for days). An ambiguous selection fails."
  - "The Proof job now provisions MinIO and libvips: check_adoption_proof_matrix.sh runs the :minio-tagged package_authority proof, which would have failed on every PR without them."
---

# Plan 211 Summary: product-only landing branch

## Result

Local branch `phase-133-landing` is green. It is in worktree `.claude/worktrees/phase133-landing`, based on `origin/main` 45ebde5e, and has not been pushed. **No requirement credit:** all five requirements remain Pending until Plan 213 evaluates main's live evidence.

- **Tested landing HEAD:** `1977f96f98f146154c0b883cec3b294a6d1de6c7`. The later commits on the branch touch only `.planning/` (this summary).
- **Manifest:** 32 product paths, byte-identical to `gsd/phase-133-execution`.
- **Excluded:** 154 basenames, including the `phase_133_*` tooling, `test/fixtures/phase133/`, `AGENTS.md`, `.tool-versions` and `prompts/`.
- **Closure check:** `check_phase_133_landing_closure.sh --source gsd/phase-133-execution --landing ../phase133-landing` exits 0, and `--self-test` passes 7/7. The self-test went red first against a stubbed checker.

## Local green on 1977f96f

All runs used the RUNNING.md toolchain: Erlang 27.3.4.15, Elixir 1.17.3-otp-27, node 22.14.0, Postgres and a local MinIO.

| Command | Result |
|---|---|
| `mix ci` | exit 0 (97 + 1591 tests, 0 failures) |
| `mix test test/install_smoke` | exit 0 (326 tests, 0 failures) |
| `bash scripts/maintainer/check_adoption_proof_matrix.sh` (with MinIO) | exit 0 |
| `bash scripts/ci/test_nightly_dialyzer.sh` | 34/34 |
| `bash scripts/ci/test_nightly_summary_gate.sh` | 49/49 |
| `bash scripts/ci/test_nightly_incident.sh` | 34/34 |
| `bash scripts/ci/test_verify_nightly_run.sh` | 187/187 |

The four harnesses also pass in a `--depth 1` clone, which mirrors the CI checkout.

## Task notes

1. **Manifest and closure check.**
   - First real run found a false positive: `verify_nightly_run.sh` names `.planning/.../133-EVIDENCE-CENSUS.json`, which shares a basename with the excluded fixture.
   - A match is now excused only when it is a full path present on the landing HEAD. A self-test case covers this.
2. **Verifier and genesis, red first.**
   - The 18 new `verify-scheduled` cases failed before implementation.
   - The 4 genesis adoption cases failed with the real-world error, "coverage incomplete through high-watermark".
   - The fail-closed cases now assert their specific reasons.
3. **Edge rows and CI wiring.**
   - Two named tests were added: EVID-01 adjacency and TRUTH-08 unclassified claims. Both go red when the guarded code is mutated.
   - The Proof job runs the four harnesses.
   - The incident harness swapped `rg` for `grep`, because the runner image does not guarantee ripgrep.
   - Two meta-test counts were updated in the same commit: `setup-minio` 7→8 and `install_apt_packages.sh` 18→19.
4. **Full local green.**
   - The first `mix ci` failed `format --check-formatted` on the new test. Fixed.
   - The first adoption-matrix run failed because MinIO was not available. That exposed the Proof-job provisioning gap, which is now fixed in ci.yml.

## Known debt

- `test_nightly_dialyzer.sh` and `verify_nightly_run.sh` hard-code `.planning/phases/133-evidence-charter-and-live-truth/` paths. They need re-pointing when phase 133 is archived to `milestones/` (see the install_smoke archive-coupling note).
- One full `mix test test/install_smoke` run failed once at the first collector call of "EVID-01: foreign SHA and dirty diagnostic receipts cannot become authoritative", with the message "detector input must resolve to a regular file within repository root". It passed alone, 3/3 file reruns and two later full-suite runs. This plan did not modify that test. It is an existing concurrency flake to watch in CI.
- The Proof job is slower now, because it runs a generated-app package proof against MinIO.

## Next

Plan 212 (wave 52). Pushing `phase-133-landing`, opening the PR and merging each need a separate authorization checkpoint.
