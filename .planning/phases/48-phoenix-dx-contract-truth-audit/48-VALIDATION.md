---
phase: 48
slug: phoenix-dx-contract-truth-audit
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir 1.19.5 |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-40 seconds quick loop; full suite is longer |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** `mix test` must be green and the truth-parity test must cover active wording, guide ownership, and archive disclaimers
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | PHX-01 / TRUTH-01 | T-48-01-01 | Active truth surfaces describe the shipped helper seam honestly and do not use stale shorthand for the whole Phoenix story. | doc parity | `rg -n 'uploader: "RindleTus"|Rindle\.LiveView\.allow_tus_upload/4|verify_completion/2' .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/STATE.md && ! rg -n 'LiveView tus uploader component' .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/STATE.md` | ✅ | ✅ green |
| 48-01-02 | 01 | 1 | TRUTH-01 | T-48-01-02 | The active roadmap stays tooling-readable so `gsd-sdk query roadmap.get-phase 48` resolves the live phase truth. | CLI + doc parity | `gsd-sdk query roadmap.get-phase 48` | ✅ | ✅ green |
| 48-02-01 | 02 | 2 | PHX-01 | T-48-02-01 | The canonical guide states the supported thin helper seam, and `Rindle.LiveView` points to it instead of duplicating operational setup. | unit + doc parity | `mix test test/rindle/live_view_test.exs && rg -n 'supported thin helper seam|uploader: "RindleTus"|consume_uploaded_entries/3|verify_completion/2' guides/resumable_uploads.md && rg -n 'guides/resumable_uploads.md' lib/rindle/live_view.ex` | ✅ | ✅ green |
| 48-02-02 | 02 | 2 | TRUTH-01 | T-48-02-02 | The three known v1.8 historical drift sources keep their original wording but add redirect notes to current truth surfaces. | doc parity | `rg -n 'Historical v1.8 note' .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md && rg -n 'guides/resumable_uploads.md|\.planning/PROJECT.md|\.planning/REQUIREMENTS.md|\.planning/ROADMAP.md' .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md && rg -n 'LiveView tus uploader component' .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md` | ✅ | ✅ green |
| 48-02-03 | 02 | 2 | PHX-01 / TRUTH-01 | T-48-02-03 | A dedicated parity test fails if active wording, guide ownership, or archive disclaimers drift. | integration | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing test infrastructure covers the phase requirements.
- [x] The quick loop is already defined and uses existing ExUnit infrastructure.
- [x] `test/install_smoke/phoenix_tus_truth_parity_test.exs` now covers active truth wording, guide ownership, and archive redirect disclaimers alongside the LiveView helper seam.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 60s for the quick loop
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready 2026-05-25

## Validation Audit 2026-05-25

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 2 |
| Escalated | 0 |
