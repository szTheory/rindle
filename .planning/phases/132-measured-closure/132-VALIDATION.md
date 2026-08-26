---
phase: 132
slug: measured-closure
status: gaps_found
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-25
---

# Phase 132 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (project-native) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_timing_automation_test.exs --seed 0` |
| **Full suite command** | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh && mix coveralls.multiple --type local --type json && bash scripts/install_smoke.sh image` |
| **Estimated runtime** | Tagged-contract runtime is measured during execution; the distinct full image integration proof is historically ~420 seconds, and full preservation runtime varies by lane |

---

## Sampling Rate

- **After the Plan 01 argv change:** Run the fast tagged generator contract immediately, then run the full image package-consumer as a distinct integration-acceptance check.
- **After the recovery topology test commit:** Run the focused CI lane, observability, and timing automation suite before changing workflow edges.
- **After the exact six-edge workflow correction:** Re-run the focused suite plus `bash scripts/ci/test_ci_summary_gate.sh` before any preservation or live timing work.
- **After every later task commit:** Run the applicable focused CI topology/gate test before its heavier preservation authority.
- **After Plan 132-12:** Run the process-level completed-state regression and shell syntax check; forged/stale completed PASS evidence must fail closed while a live-valid completed state passes without mutation.
- **After Plan 132-13:** Run formatter cleanliness plus the focused lane-split, observability, and Summary contracts before declaring the deterministic failed-run remediation green.
- **After Plan 132-14:** Run the complete ordered preservation census, one authoritative coverage command, and mutation-free no-publish preflight before any live collector is authorized.
- **During Plan 132-15:** Keep offline contract feedback before live mutation, then require the live exact-ten receipt, explicit verify, completed-state revalidation, and post-sample topology/summary checks as one uninterrupted terminal acceptance chain.
- **After every plan wave:** Run `mix quality_signals` and `bash scripts/maintainer/refactor_contract.sh`.
- **Before phase verification:** Authoritative coverage, packed image-consumer proof, automated prohibited-surface diff census, and the complete live ten-run exact-head receipt must pass.
- **Feedback latency:** The independently runnable tagged contract provides the first feedback boundary; the historically ~420-second image proof is a later integration-acceptance boundary, and live CI-14 acceptance is external and asynchronous.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 132-01-01a | 01 | 1 | CI-14 | T-132-04 | Generator argv omits pre-patch dependency installation while retaining its bounded command contract | fast contract | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract` | ✅ | ✅ green |
| 132-01-01b | 01 | 1 | CI-14 | T-132-01 | Required proof cannot bypass the post-patch package lifecycle | integration acceptance | `bash scripts/install_smoke.sh image` | ✅ | ✅ green |
| 132-02-01 | 02 | 2 | CI-14 | T-132-01 / T-132-04 | Required-job set, skip-as-pass behavior, and quoted trusted inputs remain unchanged | contract | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs`, then `bash scripts/ci/test_ci_summary_gate.sh` | ✅ | ✅ green |
| 132-02-02 | 02 | 2 | COV-05, SAFE-02 | T-132-01 | Coverage and prohibited product/release surfaces do not drift | ordered integration + contract | `mix quality_signals`; `bash scripts/maintainer/refactor_contract.sh`; one authoritative coverage run; `bash scripts/install_smoke.sh image` | ✅ | ✅ green |
| 132-03-01 | 03 | 3 | CI-14 | T-132-02 / T-132-03 | Controller owns fast-forward publication, label cleanup, exact run identity, sequencing, restart budget, and receipt arithmetic | offline orchestration | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` | ✅ | ✅ green |
| 132-03-02 | 03 | 3 | SAFE-02 | T-132-01 | Active requirements cannot close through manual verification or UAT | planning contract | `mix test test/install_smoke/automation_first_contract_test.exs --seed 0 && ./scripts/maintainer/automation_first_contract.sh` | ✅ | ✅ green |
| 132-04-01 | 04 | 4 | CI-14, COV-05, SAFE-02 | T-132-01 / T-132-04 | Final controller candidate retains every required ratchet | preservation acceptance | focused contracts, quality_signals, SAFE-01, authoritative coverage, image package-consumer | ✅ | ✅ green |
| 132-05-01 | 05 | 5 | CI-14 | T-132-02 / T-132-03 | Ten-run receipt is generated, sourced, calculated, and judged without a person | live automated acceptance | `collect_pr_timing_receipt.sh run ... && collect_pr_timing_receipt.sh verify ...` | ✅ | ❌ red |
| 132-08-X | 08 | 8 | CI-14 | — | Superseded sampler is terminalized without execution; its unchanged plan remains historical evidence and cannot enter executor dispatch | executor inventory contract | `phase-plan-index 132` reports `132-08.has_summary: true` and excludes `132-08` from `incomplete` | ✅ | ✅ terminal |
| 132-09-01 | 09 | 9 | CI-14, SAFE-02 | T-132-09-01 / T-132-09-03 | RED source contract identifies exactly the six authorized edges while deterministic fixture projection reproduces the baseline and both critical branches | source-bound TDD tracer | tagged `phase_132_topology_recovery` run must fail at named `D-08 exact six-edge topology` case before workflow edit | ✅ extend + fixture | ⬜ pending |
| 132-09-02 | 09 | 9 | CI-14, COV-05, SAFE-02 | T-132-09-01 / T-132-09-02 | Exact six-edge GREEN preserves affected job bodies, adopter prerequisites, all summary/observability members, sole Summary, skip-as-pass, and an exact three-deletion/zero-addition workflow patch | source-bound + exact-patch contract | normalize only zero-context diff metadata, require exactly three authorized removed declarations, then run focused ExUnit/Bash contracts and `git diff --check` | ✅ extend | ⬜ pending |
| 132-10-01 | 10 | 10 | CI-14, COV-05, SAFE-02 | T-132-10-01 / T-132-10-02 / T-132-10-03 | Immutable topology subject retains focused proof, quality, SAFE-01, automation policy, hygiene, inclusive authoritative coverage, packed consumer, and no-trigger sampler preflight | preservation acceptance | focused contracts; `mix quality_signals`; SAFE-01; automation-first; hygiene; one authoritative coverage run; fail-closed ExCoveralls count/ratio extraction plus exact receipt comparison; packed image consumer | ✅ | ⬜ pending |
| 132-11-01 | 11 | 11 | CI-14, COV-05, SAFE-02 | T-132-11-01 / T-132-11-02 / T-132-11-04 | One locked controller yields exactly ten consecutive successful attempt-1 PR runs on the preserved head and independently enforces inclusive 480/600 or honest gaps_found | live automated acceptance | `collect_pr_timing_receipt.sh run ...` once, then conditional API-backed `verify` plus focused topology/summary contracts | ✅ | ⬜ pending |
| 132-12-01 | 12 | 12 | CI-14, SAFE-02 | T-132-12-01 / T-132-12-02 / T-132-12-03 | Completed PASS state is never trusted from local bytes: forged/stale live disagreement fails without receipt, label, or run-count mutation, while valid completed state is API-revalidated without retriggering | process-level controller regression | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0 && bash -n scripts/ci/collect_pr_timing_receipt.sh && ./scripts/maintainer/automation_first_contract.sh` | ✅ extend | ⬜ pending |
| 132-13-01 | 13 | 12 | CI-14, SAFE-02 | T-132-13-01 / T-132-13-02 / T-132-13-03 | Both failed recovery runs are bound to the same formatter failure, and canonical formatting changes no D-08/D-09 topology, fixture, required-member, or Summary behavior | formatter + topology contract | `mix format --check-formatted test/install_smoke/ci_lane_split_test.exs && mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0 && bash scripts/ci/test_ci_summary_gate.sh && ./scripts/maintainer/automation_first_contract.sh` | ✅ | ⬜ pending |
| 132-14-01 | 14 | 13 | CI-14, COV-05, SAFE-02 | T-132-14-01 / T-132-14-02 / T-132-14-03 / T-132-14-04 | Final immutable subject passes formatter/topology/quality/SAFE-01/coverage/packed-consumer preservation, inclusive 82.13% integer proof, bounded drift census, and mutation-free no-publish preflight | ordered preservation acceptance | Run the exact multiline `132-14-PLAN.md` automated command: after all local authorities it derives the last recorded correction/preserved SHAs, snapshots PR head, owned-label set, PR/head/event/workflow-scoped attempt-1 run IDs, state/lock presence and hashes, receipt hash, and all current-marker counts/content hash; invokes `collect_pr_timing_receipt.sh preflight --repo szTheory/rindle --pr 96 --workflow ci.yml --summary-job "CI Summary" --label ci-timing-sample --samples 10 --max-sequences 2 --median-max 480 --p95-max 600 --correction-sha "$CORRECTION_SHA" --preserved-subject-sha "$PRESERVED_SHA" --receipt .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md --state-dir .gsd/ci-timing/phase-132-final-preflight --no-publish`; then equality-checks every snapshot | ✅ | ⬜ pending |
| 132-15-01 | 15 | 14 | CI-14, COV-05, SAFE-02 | T-132-15-01 / T-132-15-02 / T-132-15-03 / T-132-15-04 / T-132-15-05 | One locked live collector produces exactly ten consecutive attempt-1 PR successes; explicit verify and completed-state resume re-resolve identity, chronology, sorting, median/p95, and inclusive thresholds without an eleventh sample | terminal live automated acceptance | Run the exact multiline `132-15-PLAN.md` automated command: define `RUN_CMD=(bash scripts/ci/collect_pr_timing_receipt.sh run --repo szTheory/rindle --pr 96 --workflow ci.yml --summary-job "CI Summary" --label ci-timing-sample --samples 10 --max-sequences 2 --median-max 480 --p95-max 600 --correction-sha "$CORRECTION_SHA" --preserved-subject-sha "$PRESERVED_SHA" --receipt .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md --state-dir .gsd/ci-timing/phase-132-final --publish-head)`; execute it once; require complete state plus exactly ten rows/markers; run explicit API verify; snapshot receipt hash/current counts/state run count/scoped workflow IDs; execute the identical `RUN_CMD` again; assert all snapshots unchanged, label/lock absent, and rerun the post-sample contracts | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Add a focused contract that fails if generator dependencies are installed before the repository patch while still proving downstream package provenance and image lifecycle behavior.
- [x] Add an offline stateful-gh contract for unattended live timing orchestration and bounded restart.
- [x] Add an executable planning contract that rejects human verification/UAT.
- [x] Existing ExUnit infrastructure and CI contract suites require no new framework or dependency.
- [ ] 132-09 extends the topology contract to assert D-08's exact six removed edges, D-09's unchanged edges/job bodies, complete `CI Summary` and observability membership, and unchanged skip-as-pass evaluation.
- [ ] 132-09 adds deterministic fixture arithmetic showing the approved ordering removes both measured critical branches; local/projection timing remains non-accepting for CI-14.
- [ ] 132-12 extends the existing process-level controller suite with a fail-first forged/stale completed-state regression and a positive no-retrigger resume case; no new framework or dependency is required.

---

## Manual-Only Verifications

None. Every Phase 132 requirement has an automated contract, preservation authority, or live evidence collector. External-runner exceptions are not used by the unattended path.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Fast tagged-contract feedback is recorded before the distinct full image integration acceptance
- [x] Plans 132-12 through 132-15 each have a current automated row, threat mapping, wave assignment, and explicit evidence authority
- [x] Sampling continuity through Waves 12–14 is preserved: controller regression → formatter/topology proof → final preservation/no-publish preflight → terminal live receipt and completed-state verification
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** recovery revision pending. Earlier automated evidence remains `gaps_found`; Waves 12–14
now require the completed-state forged/stale regression, formatter/topology remediation proof, final
preservation and no-publish preflight, and a fresh API-backed exact-ten receipt with explicit plus
completed-state live verification. No manual verification or UAT may close CI-14.
