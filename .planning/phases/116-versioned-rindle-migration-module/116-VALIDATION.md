---
phase: 116
slug: versioned-rindle-migration-module
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-01
---

# Phase 116 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit through Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` |
| **Full suite command** | `mix ci` plus `bash scripts/install_smoke.sh image` when generated-app smoke helpers change |
| **Estimated runtime** | quick suite under 120 seconds locally; install smoke is environment-dependent |

---

## Sampling Rate

- **After every task commit:** Run the focused test file for the touched surface.
- **After docs edits:** Run `mix test test/install_smoke/docs_parity_test.exs --seed 0`.
- **After migration API or doctor/runtime edits:** Run the quick run command above.
- **After generated-app helper edits:** Run `bash scripts/install_smoke.sh image` when local dependencies are available.
- **Before `/gsd:verify-work`:** `mix ci` must be green; install smoke must be run or explicitly documented as environment-blocked.
- **Max feedback latency:** 120 seconds for focused ExUnit feedback.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 116-01-01 | TBD | TBD | MIGRATE-01 | T-116-01 | Migration options validate `:version` and `:prefix`; invalid versions/options fail loudly. | unit | `mix test test/rindle/migration_test.exs --seed 0` | No, Wave 0 creates `test/rindle/migration_test.exs` | pending |
| 116-01-02 | TBD | TBD | MIGRATE-01 | T-116-02 | `Rindle.Migration.up/1` is idempotent, default-prefix `public`, and records a Rindle-owned version marker. | integration | `mix test test/rindle/migration_test.exs --seed 0` | No, Wave 0 creates `test/rindle/migration_test.exs` | pending |
| 116-01-03 | TBD | TBD | MIGRATE-02 | T-116-03 | `Rindle.Migration.down/1` drops only Rindle-owned tables/marker objects and never drops `oban_jobs`. | integration | `mix test test/rindle/migration_test.exs --seed 0` | No, Wave 0 creates `test/rindle/migration_test.exs` | pending |
| 116-02-01 | TBD | TBD | MIGRATE-01 | T-116-04 | Doctor accepts both fresh marker/catalog installs and healthy legacy file-history installs. | unit | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` | Yes | pending |
| 116-02-02 | TBD | TBD | MIGRATE-01, MIGRATE-02 | T-116-05 | Runtime status preflights missing Rindle tables and host-owned Oban readiness with actionable setup errors. | unit | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` | Yes | pending |
| 116-03-01 | TBD | TBD | MIGRATE-01, MIGRATE-02 | T-116-06 | README, getting-started, and upgrading teach pinned `Rindle.Migration` plus host-owned `Oban.Migration`, and reject raw greenfield package-path installs. | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | Yes | pending |
| 116-03-02 | TBD | TBD | MIGRATE-02 | T-116-07 | Generated-app proof runs separate host Oban and Rindle migrations and asserts Rindle did not create `oban_jobs`. | smoke | `bash scripts/install_smoke.sh image` | Yes helper/test; needs update | pending |
| 116-04-01 | TBD | TBD | MIGRATE-01, MIGRATE-02 | T-116-08 | CI/release invariants remain unchanged: `.github/workflows/ci.yml`, `name: CI`, and release gate behavior are not weakened. | source assertion | `git diff -- .github/workflows/ci.yml .github/workflows/release.yml` | Yes | pending |

---

## Wave 0 Requirements

- [ ] `test/rindle/migration_test.exs` - new migration API contract tests for option validation, idempotent `up/1`, scoped `down/1`, marker behavior, default `public` prefix, and no `oban_jobs` ownership.
- [ ] `test/install_smoke/docs_parity_test.exs` - update or extend existing docs parity assertions for the pinned `Rindle.Migration` snippets and raw-package-path rejection.
- [ ] `test/install_smoke/support/generated_app_helper.ex` - update generated app migration proof to create host Oban and Rindle migrations separately.
- [ ] `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs`, `test/rindle/ops/runtime_status_test.exs`, and `test/rindle/runtime_status_task_test.exs` - extend hybrid migration health and setup-failure coverage.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Generated-app install smoke when local image runtime dependencies are unavailable | MIGRATE-02 | Local `vips` or MinIO setup may be missing even though CI can run the lane. | If `bash scripts/install_smoke.sh image` cannot run locally due to host dependencies, record the exact missing dependency and require CI/package-consumer proof before closeout. |
| Release-train invariant review | MIGRATE-01, MIGRATE-02 | Source checks can show diffs, but the operator must confirm no release-gate weakening was intentional. | Review `git diff -- .github/workflows/ci.yml .github/workflows/release.yml` and confirm no `CI Summary` or release full-verification weakening. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 120 seconds for focused ExUnit checks.
- [ ] `nyquist_compliant: true` set in frontmatter after plans assign task IDs and verification coverage.

**Approval:** pending
