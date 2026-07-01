---
phase: 115
slug: versioning-readme-positioning
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-01
---

# Phase 115 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Quick: ~10-30 seconds; full: project CI-equivalent runtime |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace`
- **After every plan wave:** Run `mix ci` when test code changes; otherwise run docs parity plus `./scripts/maintainer/check_docs_links.sh`
- **Before `/gsd:verify-work`:** `mix ci` or the maintainer-approved equivalent must be green
- **Max feedback latency:** Quick docs parity feedback should stay under 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 115-01-01 | 01 | 1 | VERSION-01 | N/A | N/A | docs parity | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` | W0 | pending |
| 115-01-02 | 01 | 1 | VERSION-02 | N/A | N/A | docs parity | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` | W0 | pending |
| 115-01-03 | 01 | 1 | README-01 | N/A | Avoid overclaiming dependency-free runtime behavior | docs parity | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` | W0 | pending |
| 115-01-04 | 01 | 1 | README-02 | N/A | N/A | docs parity | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` | W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/install_smoke/docs_parity_test.exs` reads `CONTRIBUTING.md` in setup.
- [ ] `test/install_smoke/docs_parity_test.exs` asserts README and CONTRIBUTING include the pre-1.0 stability contract and 1.0 meaning.
- [ ] `test/install_smoke/docs_parity_test.exs` asserts `guides/upgrading.md` has a reusable versioned structure while preserving existing pre-0.1.4 upgrade proof content.
- [ ] `test/install_smoke/docs_parity_test.exs` asserts the README image-first first attachment section appears before the AV quickstart section.
- [ ] `test/install_smoke/docs_parity_test.exs` asserts README contains the "what Rindle is not / when not to use it" boundary.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README prose remains honest about FFmpeg/libvips | README-01 | Tests can lock strings/order, but final prose needs human review for overclaiming | Confirm the image-first first-run path does not say full background image promotion or variant processing is libvips-free. It may say the first original attachment path avoids FFmpeg and AV setup, and it must send users to RUNNING.md for image variants/libvips and AV/FFmpeg. |
| Upgrade guide remains useful, not just structurally valid | VERSION-02 | Tests can lock headings and preserved commands, but usefulness is editorial | Confirm `guides/upgrading.md` separates changelog "what changed" from upgrade-guide "what to do", includes an Unreleased/Next home, and keeps the current pre-0.1.4 upgrade path intact as a versioned entry. |

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency target < 60s for quick docs parity
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
