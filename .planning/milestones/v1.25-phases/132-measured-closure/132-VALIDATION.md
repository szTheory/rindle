---
phase: 132
slug: measured-closure
status: validated
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
- **After Plan 132-12:** Run the process-level publication/canonical-population/completed-state regressions and shell syntax check; publication success must become sample 1 with nine later triggers, failed/cancelled/attempt-2 publication must consume sequence 1, and explicit `verify --pr`/completed verification must share one repository/workflow/numeric-PR/full-SHA/boundary authority. Require live 480/600 equality, return the honest timing-miss result for 481 median or 601 p95, and reject missing/wrong PR, same-SHA other-PR association, CLI/state/source/API mismatch, forged/API/integrity/population failures without receipt, state, label, lock, or run-population mutation. Exercise exact-head and strict-ancestor publication-ready `preflight --no-publish`, non-ancestor and unauthorized transition rejection, and before/after equality for remote head, label, runs, state/lock, receipt hash, markers, and mutation counters.
- **After Plan 132-13:** Run formatter cleanliness plus the focused lane-split, observability, and Summary contracts before declaring the deterministic failed-run remediation green.
- **After Plan 132-14:** Record a new post-132-13 preserved subject and one marker-bounded two-stage transition manifest binding repository `szTheory/rindle` and numeric PR `96`: prior subject -> Plan 12 controller/test correction, then Plan 12 correction -> Plan 13 formatter-only target, with exact name/status, planning-path, and target blob evidence. Run the complete ordered preservation census, one authoritative coverage command, and successful mutation-free strict-ancestor no-publish preflight with that manifest before any live collector is authorized.
- **During Plan 132-15:** Keep offline contract feedback before live mutation, reparse and pass the same repository/PR-bound manifest through publication-ready no-publish preflight and run, then require publication sample 1 plus nine label samples, full bound-PR eligible-population equality, explicit `verify --repo "$REPO" --pr "$PR"`, completed-state live threshold revalidation, source/state/CLI/API identity agreement, same-SHA other-PR exclusion without selecting around a PR-96 success, no eleventh run/state/receipt mutation, and post-sample topology/summary checks as one uninterrupted terminal acceptance chain.
- **After every plan wave:** Run `mix quality_signals` and `bash scripts/maintainer/refactor_contract.sh`.
- **Before phase verification:** Authoritative coverage, packed image-consumer proof, automated prohibited-surface diff census, and the complete live ten-run exact-head receipt must pass.
- **Feedback latency:** The independently runnable tagged contract provides the first feedback boundary; the historically ~420-second image proof is a later integration-acceptance boundary, and live CI-14 acceptance is external and asynchronous.

---

## Per-Task Verification Map

| Plan | Requirements | Automated authority | Final status |
|------|--------------|---------------------|--------------|
| 132-01 | CI-14, SAFE-02 | Generator-order contract and packed image consumer | Green |
| 132-02 | CI-14, COV-05, SAFE-02 | Topology, Summary, quality, coverage, SAFE-01, and consumer census | Green |
| 132-03 | CI-14, SAFE-02 | Offline controller and automation-first parser suites | Green |
| 132-04 | CI-14, COV-05, SAFE-02 | Immutable preservation census | Green |
| 132-05 | CI-14 | Automated live run honestly failed and routed to remediation | Superseded |
| 132-06 | CI-14, SAFE-02 | Install-first/fallback-refresh helper regressions | Green |
| 132-07 | CI-14, COV-05, SAFE-02 | Post-remediation preservation census | Green |
| 132-08 | CI-14 | Executor inventory terminalized the superseded plan | Terminal |
| 132-09 | CI-14, COV-05, SAFE-02 | Exact six-edge topology and deterministic projection contract | Green |
| 132-10 | CI-14, COV-05, SAFE-02 | Immutable topology preservation and no-trigger preflight | Green |
| 132-11 | CI-14 | Bounded live run honestly failed and routed to controller repair | Superseded |
| 132-12 | CI-14, SAFE-02 | Canonical population, threshold, identity, and no-mutation regressions | Green |
| 132-13 | CI-14, SAFE-02 | Formatter/topology preservation proof | Green |
| 132-14 | CI-14, COV-05, SAFE-02 | Transition-manifest controller regression | Green |
| 132-15 | CI-14, COV-05, SAFE-02 | Post-repair preservation and mutation-free preflight | Green |
| 132-16 | CI-14, SAFE-02 | Preserved-tail controller regression | Green |
| 132-17 | CI-14, COV-05, SAFE-02 | Post-controller-fix preservation census | Green |
| 132-18 | CI-14 | Bounded API-backed run honestly exposed controller gaps | Superseded |
| 132-19 | CI-14, SAFE-02 | Terminal-state, deadline, resume, and pagination regressions | Green |
| 132-20 | CI-14, COV-05, SAFE-02 | Repaired-source preservation and publication readiness | Green |
| 132-21 | CI-14 | Exact-ten live receipt: 453s median / 481s p95 | Green |
| 132-22 | CI-14, COV-05, SAFE-02 | Deadline-owner and syntax-independent policy regressions plus final verifier | Green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Add a focused contract that fails if generator dependencies are installed before the repository patch while still proving downstream package provenance and image lifecycle behavior.
- [x] Add an offline stateful-gh contract for unattended live timing orchestration and bounded restart.
- [x] Add an executable planning contract that rejects human verification/UAT.
- [x] Existing ExUnit infrastructure and CI contract suites require no new framework or dependency.
- [ ] 132-09 extends the topology contract to assert D-08's exact six removed edges, D-09's unchanged edges/job bodies, complete `CI Summary` and observability membership, and unchanged skip-as-pass evaluation.
- [x] 132-09 added deterministic fixture arithmetic for both measured critical branches; projection evidence remains non-accepting for CI-14.
- [x] 132-12 added process-level canonical-population, identity, threshold, no-retrigger, preflight, and no-mutation regressions.

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
- [x] Sampling continuity through Waves 12–15 is preserved: controller/threshold/preflight regression → formatter/topology proof → manifest-bound preservation and successful no-publish preflight → terminal live receipt and completed-state verification
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-28. The final Phase 132 verifier passed all three requirements after
Plans 19–22 closed the controller and policy gaps; no manual verification or UAT closes CI-14.

## Validation Audit 2026-08-28

| Metric | Count |
|--------|------:|
| Historical red/superseded live attempts | 3 |
| Final green or terminal plan outcomes | 22 |
| Remaining validation gaps | 0 |
