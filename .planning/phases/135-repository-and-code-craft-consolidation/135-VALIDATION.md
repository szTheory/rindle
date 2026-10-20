---
phase: "135"
slug: "repository-and-code-craft-consolidation"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-18"
---

# Phase 135 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 135-RESEARCH.md § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17.3 / OTP 27 canonical; 1.15 / OTP 26 also gates `quality`), plus bash harnesses (`scripts/ci/test_*.sh`, "pass N/N" style) |
| **Config file** | `test/test_helper.exs`; `mix.exs` aliases (`test`, `ci`, `credo_quality`, `refactor_contract`) |
| **Quick run command** | The focused harness or test for the task, e.g. `bash scripts/ci/test_repo_hygiene_check.sh` or `mix test test/install_smoke/live_residue_scan_test.exs` |
| **Full suite command** | `mix ci` (needs Postgres) and `bash scripts/maintainer/refactor_contract.sh` |
| **Estimated runtime** | quick ~5–60 s; full `mix ci` ~10 min |

Local env: `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test`. Run `mix deps.get` in the executing worktree first.

---

## Sampling Rate

- **After every task commit:** the focused harness or test for that task.
- **After every plan wave:** `bash scripts/maintainer/refactor_contract.sh`, `mix credo_quality`, `mix test` on the touched directories, and every `scripts/ci/test_*.sh` added so far.
- **Before `/gsd-verify-work`:**
  - `mix ci` green.
  - PR `CI Summary` green.
  - Post-merge main push run green, which covers the main-only lanes.
  - `./scripts/maintainer/repo_hygiene_check.sh --ci` PASS.
- **Max feedback latency:** 60 s for task-level checks.

---

## Per-Requirement Verification Map

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| CRAFT-03 | Every tracked path in exactly one ledger class; every ignore rule accounted for; no tracked-ignored file; required fields present | script (bash+jq) | `bash scripts/maintainer/validate_artifact_ledger.sh --offline` | ❌ W0 | ⬜ pending |
| CRAFT-03 | Rejects an uncovered file, a double-classified file, a missing field, a stale ignore rule, a tracked-ignored file, a shipped class missing from `files:` | harness | `bash scripts/ci/test_validate_artifact_ledger.sh` | ❌ W0 | ⬜ pending |
| CRAFT-03 | The ledger-derived shipped set equals the unpacked package; regeneration leaves an empty diff | ExUnit | `mix test test/install_smoke/artifact_package_set_test.exs` | ❌ W0 | ⬜ pending |
| CRAFT-04 | No unallowlisted planning-era identifier; stale allowlist entries rejected; planted violations detected; zero `pending-removal` at close | ExUnit | `mix test test/install_smoke/live_residue_scan_test.exs` | ❌ W0 | ⬜ pending |
| CRAFT-06 | Mojibake, duplicated prose, narration and artifact comments rejected; the regression literal does not self-flag | ExUnit | same file, class-specific describe blocks | ❌ W0 | ⬜ pending |
| CRAFT-05 | Every trace entry cites a frozen candidate id, a removed baseline identity and proof commands | script | `bash scripts/maintainer/validate_readability_trace.sh --offline` | ❌ W0 | ⬜ pending |
| CRAFT-05 | No contract drift: SAFE-01 set, credo baseline, public-export snapshot, forbidden-path boundary | script + ExUnit | `bash scripts/maintainer/refactor_contract.sh && mix credo_quality && mix test test/rindle/public_surface_snapshot_test.exs && bash scripts/maintainer/craft_boundary_check.sh origin/main` | partial | ⬜ pending |
| HYGIENE-03 | Each forced failure BLOCKs: fetch failure, wrong branch or detached HEAD, behind/ahead, junk, drift, `mix ci` non-zero or missing sentinel, post-verification residue; the publish race is WARN in `--ci` and BLOCK in release-prep | harness (real git + shims) | `bash scripts/ci/test_repo_hygiene_check.sh` | ❌ W0 | ⬜ pending |
| HYGIENE-03 | No false red on current main | script | `bash scripts/maintainer/repo_hygiene_check.sh --ci` | ✅ | ⬜ pending |
| All | Planning artifacts stay automation-first | script | `./scripts/maintainer/automation_first_contract.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/maintainer/validate_artifact_ledger.sh` + `scripts/ci/test_validate_artifact_ledger.sh` (CRAFT-03)
- [ ] Residue scanner + allowlist + `test/install_smoke/live_residue_scan_test.exs` (CRAFT-04/06)
- [ ] `scripts/ci/test_repo_hygiene_check.sh` (HYGIENE-03)
- [ ] `test/rindle/public_surface_snapshot_test.exs` + fixture, `craft_boundary_check.sh`, trace validator (CRAFT-05)

---

## Manual-Only Verifications

All phase behaviors have automated verification. Merges are authorized actions only and never satisfy a requirement.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
