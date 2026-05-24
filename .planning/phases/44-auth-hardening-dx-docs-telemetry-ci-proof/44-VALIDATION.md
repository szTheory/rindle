---
phase: 44
slug: auth-hardening-dx-docs-telemetry-ci-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-23
---

# Phase 44 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir/Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/upload/tus_plug_test.exs test/rindle/error_test.exs test/rindle/ops/runtime_checks_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~45-90 seconds for quick loop; install smoke is separate and slower |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/upload/tus_plug_test.exs test/rindle/error_test.exs test/rindle/ops/runtime_checks_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** `bash scripts/install_smoke.sh tus` must pass locally when feasible, or in CI as the merge-blocking package-consumer lane
- **Max feedback latency:** 90 seconds for the quick loop

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-01-01 | 01 | 1 | TUS-10 | V2/V4 | Resume authorizer accepts `:ok`, rejects with `401`, and signature failures never return `200` | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ✅ | ⬜ pending |
| 44-01-02 | 01 | 1 | POLISH-02 | V5 | Webhook raw-body fallback stays capped and trust-boundary review debt is either closed or explicitly waived | unit + review | `mix test test/rindle/delivery/webhook_plug_test.exs` | ✅ | ⬜ pending |
| 44-02-01 | 02 | 2 | TUS-11 | V4/V5 | Locked tus reason atoms and fix-oriented `Rindle.Error.message/1` contract remain stable | unit | `mix test test/rindle/error_test.exs` | ✅ | ⬜ pending |
| 44-02-02 | 02 | 2 | TUS-12 | V3/V6 | Resumable telemetry emits the existing namespace with allowlisted metadata only | unit + contract | `mix test test/rindle/upload/resumable_telemetry_test.exs test/rindle/contracts/telemetry_contract_test.exs --include contract` | ✅ | ⬜ pending |
| 44-02-03 | 02 | 2 | TUS-13 | V4 | Doctor flags `:tus_profiles` capability/config drift without route introspection | unit | `mix test test/rindle/ops/runtime_checks_test.exs` | ✅ | ⬜ pending |
| 44-03-01 | 03 | 3 | TUS-14 | V2/V3/V4 | Guide, generated-app helper, and package-consumer tus proof stay aligned for drop-and-resume | integration | `bash scripts/install_smoke.sh tus` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing test infrastructure covers the phase requirements.
- [x] TUS-14 is tied to Plan 03 and uses the real package-consumer command `bash scripts/install_smoke.sh tus`.
- [x] Docs verification stays explicit: Plan 03 must include either docs-parity assertions or manual guide verification for the modern `@uppy/tus` split.
- [x] POLISH-02 must stay explicit in plan tasks so WR-01 cannot disappear behind already-closed Phase 35 warnings.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Modern `@uppy/tus` guidance is version-correct and clearly separated from raw `tus-js-client` guidance | TUS-14 | Upstream docs drift is editorial and may not be fully locked by current automated tests | Review `guides/resumable_uploads.md` against current Uppy docs, then confirm copied examples do not mention removed options unless explicitly version-pinned |
| Remaining Phase 35 warning debt is resolved or waived with rationale | POLISH-02 | Advisory review closure is partly a planning/documentation decision, not purely executable behavior | Compare plan outcome against `.planning/milestones/v1.6-phases/35-signed-webhook-plug-idempotent-ingest/35-REVIEW.md` and record WR-01 as fixed plus WR-02..WR-06 as already resolved or explicitly waived |

---

## Validation Sign-Off

- [x] All planned behaviors have automated verification or explicit manual coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 90s for the quick loop
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
