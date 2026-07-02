---
phase: 114
slug: oss-trust-governance
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-30
updated: 2026-07-02
validated: 2026-07-02
---

# Phase 114 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` (excludes :integration/:minio/:contract/:adopter by default) |
| **Quick run command** | `mix test test/install_smoke/package_metadata_test.exs` |
| **Full suite command** | `mix ci` (mirrors merge-blocking Quality lane) |
| **Estimated runtime** | ~10–30 seconds (governance/meta tests only) |

---

## Sampling Rate

- **After every task commit:** Run the relevant `test/install_smoke/` meta-test
- **After every plan wave:** Run `mix test test/install_smoke/`
- **Before `/gsd-verify-work`:** `mix ci` must be green (the merge-blocking set)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 114-01-01 | 01 | 1 | TRUST-01 | — | `SECURITY.md` present with disclosure policy | meta/file-exists | `mix test test/install_smoke/governance_files_test.exs` | ✅ exists | ✅ green |
| 114-01-02 | 01 | 1 | TRUST-02 | — | `CODE_OF_CONDUCT.md` present | meta/file-exists | `mix test test/install_smoke/governance_files_test.exs` | ✅ exists | ✅ green |
| 114-01-03 | 01 | 1 | TRUST-03 | — | issue templates + PR template present | meta/file-exists | `mix test test/install_smoke/governance_files_test.exs` | ✅ exists | ✅ green |
| 114-02-01 | 02 | 1 | META-01 | — | `package.links` has Changelog + Docs | meta/metadata | `mix test test/install_smoke/package_metadata_test.exs` | ✅ exists | ✅ green |
| 114-02-02 | 02 | 1 | META-02 | — | release public verification checks Hex API owner `sztheory` | release/public-api | `mix test test/install_smoke/package_metadata_test.exs` | ✅ exists | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/install_smoke/governance_files_test.exs` — new meta-test asserting `SECURITY.md`, `CODE_OF_CONDUCT.md`, `.github/ISSUE_TEMPLATE/` forms, `.github/PULL_REQUEST_TEMPLATE.md` exist (TRUST-01/02/03)
- [x] **Edit** `test/install_smoke/package_metadata_test.exs:~73` — the existing `links` assertion equals GitHub-only and MUST be updated to expect Changelog + Docs in the SAME wave as the mix.exs edit (META-01 coupling footgun)

*Governance files are repo-only (root + `.github/`) and intentionally NOT added to mix.exs `files:`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GitHub "Report a vulnerability" button appears | TRUST-01 | Requires toggling repo Setting (Settings > Code security > Private vulnerability reporting); not assertable from the repo tree | After merge, enable Private Vulnerability Reporting and confirm the button renders on the Security tab |

*All in-repo behaviors have automated verification; only the GitHub repo-settings toggle is manual.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** passed

## Validation Audit 2026-07-02

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Phase verification later proved all Phase 114 requirements with automated evidence: governance file
presence tests, package metadata tests, release workflow/verifier wiring assertions, shell syntax checks,
full `mix ci`, and maintainer-confirmed Private Vulnerability Reporting UAT. No additional tests were required.
