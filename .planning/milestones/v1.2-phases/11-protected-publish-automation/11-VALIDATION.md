---
phase: 11
slug: protected-publish-automation
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash |
| **Config file** | none — script |
| **Quick run command** | `bash scripts/assert_version_match.sh` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/assert_version_match.sh`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | RELEASE-06 | — | Hex publish via GHA | unit/workflow | (Verified by GHA environment config) | ✅ | ✅ green |
| 11-02-01 | 02 | 2 | RELEASE-07 | — | Abort on version mismatch | script | `bash scripts/assert_version_match.sh` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `scripts/assert_version_match.sh` — exists and executable; validated by `11-VERIFICATION.md` behavioral spot-check (`Version matches: 0.1.0-dev`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex API Key | RELEASE-06 | Superseded — automated CI dry-run (`mix hex.publish --dry-run --yes`) in the `package-consumer` job verifies the publish path without a live secret; `11-VERIFICATION.md` confirms "Human Verification Required: None" | Verified automatically by CI per `11-03-SUMMARY.md` and `11-VERIFICATION.md` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
