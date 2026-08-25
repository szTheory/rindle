---
phase: 132
slug: measured-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
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
- **Before `$gsd-verify-work`:** Authoritative coverage, packed image-consumer proof, bounded prohibited-surface diff review, and the complete live ten-run exact-head receipt must pass.
- **Feedback latency:** The independently runnable tagged contract provides the first feedback boundary; the historically ~420-second image proof is a later integration-acceptance boundary, and live CI-14 acceptance is external and asynchronous.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 132-01-01a | 01 | 1 | CI-14 | T-132-04 | Generator argv omits pre-patch dependency installation while retaining its bounded command contract | fast contract | `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract` | ❌ W0 focused ordering contract | ⬜ pending |
| 132-01-01b | 01 | 1 | CI-14 | T-132-01 | Required proof cannot bypass the post-patch package lifecycle | integration acceptance | `bash scripts/install_smoke.sh image` | ✅ | ⬜ pending |
| 132-02-01 | 02 | 2 | CI-14 | T-132-01 / T-132-04 | Required-job set, skip-as-pass behavior, and quoted trusted inputs remain unchanged | contract | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs`, then `bash scripts/ci/test_ci_summary_gate.sh`; stop at the first failure | ✅ | ⬜ pending |
| 132-02-02 | 02 | 2 | COV-05, SAFE-02 | T-132-01 | Coverage and prohibited product/release surfaces do not drift | ordered integration + contract | Run independently in order, stopping at the first failure: `mix quality_signals`; `bash scripts/maintainer/refactor_contract.sh`; `mix coveralls.multiple --type local --type json`; `test -s cover/excoveralls.json`; the documented `jq -e` inclusive-threshold check; `bash scripts/install_smoke.sh image` | ✅ | ⬜ pending |
| 132-03-01 | 03 | 3 | CI-14 | T-132-02 / T-132-03 | Receipt excludes reruns, mixed heads, cancellations, and unsupported runner exceptions | live acceptance | read-only `gh api` receipt collection from one immutable implementation SHA | manual/external | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add a focused contract that fails if generator dependencies are installed before the repository patch while still proving downstream package provenance and image lifecycle behavior.
- [x] Existing ExUnit infrastructure and CI contract suites require no new framework or dependency.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Ten-run CI timing acceptance | CI-14 | Requires live GitHub Actions runs on one immutable PR head | Collect ten consecutive successful, non-cancelled, first-attempt `pull_request` runs; measure workflow start through `CI Summary`; verify median ≤480 seconds and nearest-rank p95 ≤600 seconds; record run URLs, timestamps, SHA, and attempts. |
| External-runner exception, if invoked | CI-14 | Depends on external infrastructure evidence and accountable ownership | Record job-level evidence, a named owner, and a dated follow-up; otherwise classify the run as a failure, not an exception. |
| Prohibited-surface diff review | SAFE-02 | Some absence-of-drift claims require bounded human inspection | Review the final correction diff for Admin, public API, schema/migration, telemetry/error, dependency-set, and release-proof changes; record that none occurred or stop for replanning. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Fast tagged-contract feedback is recorded before the distinct full image integration acceptance
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
