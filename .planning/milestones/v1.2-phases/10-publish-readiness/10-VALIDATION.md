---
phase: 10
slug: publish-readiness
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix test tasks |
| **Config file** | `test/test_helper.exs` and project `mix test` alias in `mix.exs` |
| **Quick run command** | `mix test test/install_smoke/release_docs_parity_test.exs` or `mix test test/install_smoke/package_metadata_test.exs` |
| **Full suite command** | `mix hex.build --unpack && mix docs --warnings-as-errors && mix test` |
| **Estimated runtime** | ~25 seconds for quick probes; heavier preflight runs at wave boundaries |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/install_smoke/docs_parity_test.exs` or the task-owned targeted ExUnit file (`release_docs_parity_test.exs` / `package_metadata_test.exs`) once created
- **After every plan wave:** Run `mix hex.build --unpack && mix docs --warnings-as-errors`
- **Before `$gsd-verify-work`:** `mix hex.build --unpack && mix docs --warnings-as-errors && mix test` must be green
- **Max feedback latency:** 25 seconds for task-level probes; heavier package/docs preflight is reserved for wave gates

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | RELEASE-04 | T-10-01 | Release guidance makes owner/auth, versioning, first-publish checklist, and package-metadata review explicit without introducing live credentials | docs/policy gate | `mix test test/install_smoke/release_docs_parity_test.exs` | ✅ | ✅ green |
| 10-02-01 | 02 | 2 | RELEASE-05 | T-10-02 | Package metadata and tarball-content assertions fail fast before any wave-level preflight run | build/smoke | `mix test test/install_smoke/package_metadata_test.exs` | ✅ | ✅ green |
| 10-02-02 | 02 | 2 | RELEASE-05 | T-10-05 / T-10-06 | Workflow wiring and docs-warning cleanup are verified with the smallest direct probe before wave-close preflight | config/docs gate | `mix docs --warnings-as-errors && rg -n 'scripts/release_preflight\\.sh' .github/workflows/release.yml` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/install_smoke/release_docs_parity_test.exs` — verify maintainer release guide presence plus key owner/versioning/checklist instructions for `RELEASE-04`
- [x] `test/install_smoke/package_metadata_test.exs` — assert unpacked `hex_metadata.config` and exact package file expectations for `RELEASE-05`
- [x] Release workflow/build command for `mix docs --warnings-as-errors`
- [x] Warning cleanup for the current docs warning around `Rindle.LiveView.allow_upload/4`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm intended first-publish owner model and target release version before live publish | RELEASE-04 | Depends on maintainer/release policy, not just repo state | Review the Phase 10 release runbook, verify the named owner path and target version, then confirm they match the actual publish operator before Phase 11 wiring |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [x] Feedback latency < 30s for task-level probes
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
