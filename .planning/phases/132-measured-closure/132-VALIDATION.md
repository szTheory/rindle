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
| **Quick run command** | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract` |
| **Full suite command** | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh && mix coveralls.multiple --type local --type json && bash scripts/install_smoke.sh image` |
| **Estimated runtime** | Tagged-contract runtime is measured during execution; the distinct full image integration proof is historically ~420 seconds, and full preservation runtime varies by lane |

---

## Sampling Rate

- **After the Plan 01 argv change:** Run the fast tagged generator contract immediately, then run the full image package-consumer as a distinct integration-acceptance check.
- **After every later task commit:** Run the applicable focused CI topology/gate test before its heavier preservation authority.
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

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Add a focused contract that fails if generator dependencies are installed before the repository patch while still proving downstream package provenance and image lifecycle behavior.
- [x] Add an offline stateful-gh contract for unattended live timing orchestration and bounded restart.
- [x] Add an executable planning contract that rejects human verification/UAT.
- [x] Existing ExUnit infrastructure and CI contract suites require no new framework or dependency.

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
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated evidence complete with `gaps_found`; CI-14's 516.5-second median exceeds the
480-second target, while the 543-second p95 passes. No manual verification or UAT is required.
