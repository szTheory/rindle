---
phase: 46
slug: generated-app-tus-runtime-proof-recovery
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-24
validated: 2026-05-25
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir 1.19.5 |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` |
| **Full suite command** | `bash scripts/install_smoke.sh tus` |
| **Estimated runtime** | ~20 seconds quick loop; install smoke is slower |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/install_smoke/generated_app_smoke_test.exs --include minio`
- **After every plan wave:** Run `bash scripts/install_smoke.sh tus`
- **Before `$gsd-verify-work`:** Fresh `bash scripts/install_smoke.sh tus` output plus refreshed JSON breadcrumbs must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | TUS-14 | T-46-01 / T-46-02 | A fresh canonical rerun classifies the live branch from `bash scripts/install_smoke.sh tus` and captures the persisted breadcrumb files before any code edit. | integration | `bash scripts/install_smoke.sh tus` | ✅ | ✅ green |
| 46-01-02 | 01 | 1 | TUS-14 | T-46-01 / T-46-03 | The generated-app package-consumer lane stays green or is repaired only through the narrow install-smoke/runtime surface while preserving the real Node/MinIO/drop-and-resume contract. | integration | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio -x && bash scripts/install_smoke.sh tus` | ✅ | ✅ green |
| 46-02-01 | 02 | 2 | TUS-14 | T-46-02 / T-46-04 | `46-VERIFICATION.md` turns the live rerun outcome into durable audit evidence and explicitly supersedes stale Phase 44 blocker narrative without leaking the signed upload URL. | doc + integration | `rg -n "bash scripts/install_smoke.sh tus|install_smoke_tus_last_run|install_smoke_tus_report|install_smoke_tus_debug_report|TUS-14|superseded" .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md` | ✅ | ✅ green |
| 46-02-02 | 02 | 2 | TUS-14 | T-46-02 / T-46-04 | `46-VALIDATION.md` stays machine-greppable and Nyquist-compliant, with all four planned tasks mapped and sign-off tied to the live rerun result. | doc + integration | `rg -n "46-01-01|46-01-02|46-02-01|46-02-02|TUS-14|install_smoke_tus_last_run|bash scripts/install_smoke.sh tus" .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VALIDATION.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 44 stale-vs-current evidence is clearly superseded by Phase 46 artifacts | TUS-14 | Audit clarity depends on narrative alignment across planning and verification docs, not just command success | Compare `44-VERIFICATION.md`, `44-VALIDATION.md`, `46-VERIFICATION.md`, and `tmp/install_smoke_tus_last_run.json`; confirm the final story names the stale artifact and the fresh authoritative rerun explicitly |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or existing infrastructure
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 90s for the quick loop
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-25

---

## Validation Audit 2026-05-25

Retroactive execution audit after the fresh green rerun that closed `TUS-14`.

| Metric | Count |
|--------|-------|
| Requirements audited | 1 (`TUS-14`) |
| Tasks audited | 4 (`46-01-01`, `46-01-02`, `46-02-01`, `46-02-02`) |
| Gaps found | 0 |
| Resolved | 1 (stale verification narrative reconciled) |
| Escalated | 0 |
| Manual-only | 1 (stale-vs-current audit clarity review) |

**Method:** Ran the canonical package-consumer proof command `bash scripts/install_smoke.sh tus`, confirmed `tmp/install_smoke_tus_last_run.json` reported `tus_failure_phase: "none"` and `tus_failure_mode: "none"`, then updated the verification artifacts to cite the exact rerun, breadcrumb files, and user-visible asset facts without leaking the signed upload URL. The plan’s `mix test ... -x` helper command is stale for the current Mix CLI, so the scoped equivalent here is `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio --max-failures 1`.

**Green evidence:** `install_smoke_tus_last_run.json` now records `previous_uploads: 1`, `byte_size: 210777744`, `content_type: "video/mp4"`, and `ready_variants: ["poster", "web_720p"]`. This supersedes the stale `ECONNRESET` / `socket hang up` story preserved in Phase 44's historical verification report.
