---
phase: 116
slug: versioned-rindle-migration-module
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-01
updated: 2026-07-01
validated: 2026-07-01
---

# Phase 116 - Validation Strategy

> Per-phase validation contract for feedback sampling and Nyquist coverage.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit through Mix, plus generated-app image smoke |
| **Config file** | `test/test_helper.exs` |
| **Focused validation command** | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/package_metadata_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` |
| **Generated-app smoke command** | `bash scripts/install_smoke.sh image` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Focused suite under 120 seconds locally; generated-app smoke is environment-dependent |

---

## Input State

- **State:** A - `116-VALIDATION.md` exists and was audited.
- **Phase status:** Executed through Plans 116-01 to 116-07.
- **Summaries read:** `116-01-SUMMARY.md` through `116-07-SUMMARY.md`.
- **Result:** No Nyquist gaps remain; no user gap gate or `gsd-nyquist-auditor` spawn was required.

---

## Sampling Rate

- **After migration API or DDL edits:** Run `mix test test/rindle/migration_test.exs test/rindle/api_surface_boundary_test.exs --seed 0`.
- **After doctor or runtime-status edits:** Run `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0`.
- **After docs edits:** Run `mix test test/install_smoke/docs_parity_test.exs --seed 0`.
- **After generated-app helper edits:** Run `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0`; run `bash scripts/install_smoke.sh image` when local dependencies are available.
- **Before closeout:** Run the focused validation command, generated-app image smoke, and `mix ci`.
- **Max feedback latency:** 120 seconds for focused ExUnit feedback.

---

## Requirements Coverage Summary

| Requirement | Coverage Status | Automated Evidence |
|-------------|-----------------|--------------------|
| MIGRATE-01 | COVERED | Versioned `Rindle.Migration.up/1` and `down/1`, option validation, marker behavior, docs parity, doctor/runtime readiness, generated-app proof, and final focused suite. |
| MIGRATE-02 | COVERED | No Rindle-owned `oban_jobs` DDL, legacy Oban migration compatibility stub, host-owned `Oban.Migration` docs, doctor/runtime `oban_jobs` readiness, generated-app smoke, and release invariant audit. |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 116-01-01 | 116-01 | 1 | MIGRATE-01, MIGRATE-02 | T-116-01, T-116-02 | RED contract locks version pinning, default `public` prefix, marker behavior, idempotent up, scoped down, option validation, and no Rindle-owned Oban table creation. | contract | `mix test test/rindle/migration_test.exs --seed 0` | Yes | COVERED |
| 116-01-02 | 116-01 | 1 | MIGRATE-01, MIGRATE-02 | T-116-03, T-116-04 | Public API boundary exposes `Rindle.Migration` while helper modules stay hidden, and package metadata preserves the legacy Oban migration filename. | contract | `mix test test/rindle/api_surface_boundary_test.exs test/install_smoke/package_metadata_test.exs --seed 0` | Yes | COVERED |
| 116-02-01 | 116-02 | 1 | MIGRATE-01, MIGRATE-02 | T-116-05, T-116-06, T-116-08 | Doctor accepts fresh marker/catalog installs and healthy legacy installs while reporting missing host-owned `oban_jobs` as actionable setup. | contract | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` | Yes | COVERED |
| 116-02-02 | 116-02 | 1 | MIGRATE-01, MIGRATE-02 | T-116-07, T-116-08 | Runtime status returns bounded `setup_incomplete` errors before report queries touch missing Rindle or Oban tables. | contract | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` | Yes | COVERED |
| 116-03-01 | 116-03 | 1 | MIGRATE-01, MIGRATE-02 | T-116-09, T-116-11 | Docs parity requires pinned `Rindle.Migration`, host-owned `Oban.Migration`, rollback safety copy, and rejection of raw package-path greenfield setup. | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | Yes | COVERED |
| 116-03-02 | 116-03 | 1 | MIGRATE-01, MIGRATE-02 | T-116-10, T-116-11 | Generated-app proof requires separate host Oban and Rindle migrations and rejects fresh-install legacy package-directory resolution. | smoke contract | `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` | Yes | COVERED |
| 116-04-01 | 116-04 | 2 | MIGRATE-01 | T-116-13 | Public wrapper validates supported `:version` and `:prefix`, exposes only `up/1` and `down/1`, and avoids installer/generator scope creep. | unit | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/migration_test.exs --seed 0` | Yes | COVERED |
| 116-04-02 | 116-04 | 2 | MIGRATE-01, MIGRATE-02 | T-116-14, T-116-15 | Versioned DDL creates, upgrades, marks, and rolls back only Rindle-owned schema under the selected prefix. | integration | `mix test test/rindle/migration_test.exs --seed 0` | Yes | COVERED |
| 116-04-03 | 116-04 | 2 | MIGRATE-02 | T-116-16 | Legacy bundled Oban migration filename remains packaged but no longer creates, alters, or drops `oban_jobs`. | package contract | `mix test test/install_smoke/package_metadata_test.exs test/rindle/migration_test.exs --seed 0` | Yes | COVERED |
| 116-05-01 | 116-05 | 3 | MIGRATE-01, MIGRATE-02 | T-116-17, T-116-18, T-116-20 | Doctor readiness separates Rindle-owned schema readiness from host-owned Oban readiness and downgrades healthy legacy drift to warning/history-only. | unit | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` | Yes | COVERED |
| 116-05-02 | 116-05 | 3 | MIGRATE-01, MIGRATE-02 | T-116-19, T-116-20 | Runtime status preflight reports missing Rindle schema or host-owned `oban_jobs` without raw database crashes or mutating Oban state. | unit | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` | Yes | COVERED |
| 116-06-01 | 116-06 | 4 | MIGRATE-01, MIGRATE-02 | T-116-09, T-116-11 | README and Getting Started teach normal host migrations, pinned Rindle migration calls, and host-owned Oban setup. | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | Yes | COVERED |
| 116-06-02 | 116-06 | 4 | MIGRATE-01, MIGRATE-02 | T-116-09, T-116-11 | Upgrade, operations, and troubleshooting copy preserve legacy compatibility while directing fresh setup through `Rindle.Migration` and host-owned `Oban.Migration`. | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | Yes | COVERED |
| 116-06-03 | 116-06 | 4 | MIGRATE-01, MIGRATE-02 | T-116-10 | Generated Phoenix image smoke proves the documented install path with separate host Oban and Rindle migrations. | smoke | `bash scripts/install_smoke.sh image` | Yes | COVERED |
| 116-07-01 | 116-07 | 5 | MIGRATE-01, MIGRATE-02 | T-116-26, T-116-28 | Final focused suite, generated-app smoke, and `mix ci` validate the shipped claims without environment blocks. | verification | `mix ci` | Yes | COVERED |
| 116-07-02 | 116-07 | 5 | MIGRATE-01, MIGRATE-02 | T-116-25, T-116-27 | Release-train workflows remain unchanged and no configured schema-push trigger applies. | source audit | `git diff -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml` | Yes | COVERED |

---

## Wave 0 / Gap Closure Requirements

- [x] `test/rindle/migration_test.exs` covers option validation, idempotent `up/1`, scoped `down/1`, marker behavior, default `public` prefix, and no Rindle-owned `oban_jobs`.
- [x] `test/rindle/api_surface_boundary_test.exs` covers public `Rindle.Migration` visibility and hidden helper modules.
- [x] `test/install_smoke/package_metadata_test.exs` covers legacy packaged migration filename compatibility.
- [x] `test/install_smoke/docs_parity_test.exs` covers pinned install docs, rollback safety copy, and greenfield package-path rejection.
- [x] `test/install_smoke/support/generated_app_helper.ex` and `test/install_smoke/generated_app_smoke_test.exs` cover generated-app host Oban and Rindle migration proof.
- [x] `test/rindle/ops/runtime_checks_test.exs` and `test/rindle/doctor_test.exs` cover hybrid doctor readiness and host-owned Oban setup copy.
- [x] `test/rindle/ops/runtime_status_test.exs` and `test/rindle/runtime_status_task_test.exs` cover setup preflight and CLI failure copy.

---

## Gap Analysis

| Requirement | Status | Existing Test Coverage | Gap |
|-------------|--------|------------------------|-----|
| MIGRATE-01 | COVERED | Migration API tests, API boundary tests, docs parity, generated-app smoke, doctor/runtime focused tests, final focused suite, `mix ci` evidence in `116-07-SUMMARY.md`. | None |
| MIGRATE-02 | COVERED | Migration non-ownership tests, package metadata compatibility, docs parity, generated-app image smoke, doctor/runtime Oban readiness tests, release/source audit. | None |

No test files were generated during this validation audit because the completed phase already had automated coverage for every requirement.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | MIGRATE-01, MIGRATE-02 | No manual-only gaps remain after the 2026-07-01 audit; generated-app image smoke and release/source audits passed locally. | N/A |

---

## Validation Audit 2026-07-01

| Metric | Count |
|--------|-------|
| Requirements audited | 2 |
| Completed plan tasks audited | 16 |
| Gaps found | 0 |
| Resolved by this audit | 0 |
| Escalated manual-only | 0 |
| New test files generated | 0 |

### Audit Evidence

- `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/package_metadata_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` - PASS, 152 tests, 0 failures, 13 excluded.
- `bash scripts/install_smoke.sh image` - PASS, 3 tests, 0 failures.
- `git diff --name-only -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml && git diff -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml && test -z "$(git diff --name-only | rg '^(src/collections/.*\\.ts|src/globals/.*\\.ts|prisma/schema\\.prisma|prisma/schema/.*\\.prisma|drizzle/schema\\.ts|src/db/schema\\.ts|drizzle/.*\\.ts|supabase/migrations/.*\\.sql|src/entities/.*\\.ts|src/migrations/.*\\.ts)$' || true)"` - PASS, no workflow diffs and no configured schema-push trigger.
- `116-07-SUMMARY.md` records `mix ci` - PASS, 3 doctests, 1248 tests, 0 failures, 4 skipped, 77 excluded.

---

## Validation Sign-Off

- [x] All tasks have automated verification or final source-audit coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 references are covered by committed tests.
- [x] No watch-mode flags.
- [x] Feedback latency under 120 seconds for focused ExUnit checks.
- [x] Generated-app smoke proof passed locally.
- [x] Release-train invariants and schema-push detection audited.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** Nyquist-compliant
