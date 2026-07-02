---
phase: 113-evaluation-baseline-release-hygiene
plan: 03
subsystem: release-hygiene
tags: [junit, release-please, runbook, ci-hardening, root-cause]
requires: []
provides:
  - junit-write-path-hardening
  - corrected-stuck-release-root-cause-prose
affects:
  - scripts/public_smoke.sh
  - test/test_helper.exs
  - guides/release_publish.md
  - .planning/RELEASE-TRAIN.md
tech-stack:
  added: []
  patterns:
    - "env -u CI to gate JUnitFormatter off for a crash-prone clean-room shell-out"
key-files:
  created:
    - .planning/phases/113-evaluation-baseline-release-hygiene/113-03-SUMMARY.md
  modified:
    - scripts/public_smoke.sh
    - guides/release_publish.md
    - .planning/RELEASE-TRAIN.md
decisions:
  - "D-08: chose research option (c) — run the parent install-smoke shell-out with CI unset (env -u CI) rather than hardening test_helper.exs; tightest scope, leaves normal CI JUnit and child app JUnit untouched."
  - "D-07: recorded the CORRECTED causal chain (PR #40 = the 0.3.1 PR; :epipe/$callers fixes merged 2026-06-28; first post-fix run 2026-06-29 run 28399407429 401'd on the expired RELEASE_PLEASE_TOKEN), explicitly refuting D-04's superseded 'PR #40 was the 0.3.2 PR' framing."
metrics:
  duration: ~2m
  completed: 2026-06-30
tasks_completed: 2
tasks_total: 2
files_created: 1
files_modified: 3
status: complete
---

# Phase 113 Plan 03: Track-A Wave-1 Release Hygiene Summary

Hardened the `public_smoke.sh` JUnitFormatter write path so an abnormal-exit install-smoke suite surfaces a clean crash instead of an opaque `File.Error ... bad argument` (D-08), and recorded the corrected stuck-release root-cause chain as durable prose in the release runbook and the maintainer ledger (D-07).

## What Was Built

### Task 1 — D-08: harden the junit write path (commit d87b079)
`scripts/public_smoke.sh` `run_install_smoke_profile()` now runs the parent install-smoke shell-out with `env -u CI mix test …`. With `CI` unset, `test/test_helper.exs`'s CI-gated `JUnitFormatter` wiring does not engage for this crash-prone clean-room suite, so an `:epipe` child crash propagates as a CLEAN failure rather than being masked by a `JUnitFormatter.handle_suite_finished/1` `bad argument` written during an abnormal GenServer teardown (Pitfall 3, originally observed in run 28246413418). The normal CI JUnit suite and the child generated app's own JUnit behavior are unaffected. `test/test_helper.exs` needed no change — option (c) keeps the entire fix in the shell-out.

### Task 2 — D-07: record the corrected root cause (commit a443b46)
- `guides/release_publish.md`: new `### Stuck release: expired RELEASE_PLEASE_TOKEN (the `|| github.token` footgun)` subsection under `## Recovery Workflow Contract` (before `## Post-Publish Follow-Up`). Captures the corrected chain (PR #40 = the **0.3.1** release PR; fixes merged 2026-06-28 after the last good 2026-06-26 run; first post-fix push 2026-06-29 / run 28399407429 failed `Bad credentials` because the expired token wins the `secrets.X || github.token` `||`), the recovery steps (rotate token → relabel pending→tagged → re-trigger), the `Actions: write` dispatch-403 footgun, the "three fixes in series" record of what actually unstuck 0.3.2 (published+verified via run 28420598348), and the prevention guards.
- `.planning/RELEASE-TRAIN.md`: dated `2026-06-29` Verification-Log row — "Release-please stuck: 0.3.2 PR never opened / Root-caused + guarded" citing run 28399407429 and the `||` mask.

## Verification

| Check | Result |
|-------|--------|
| `bash -n scripts/public_smoke.sh` | valid |
| `mix test test/install_smoke/package_metadata_test.exs` | 15 tests, 0 failures |
| junit/CI grep present in public_smoke.sh + test_helper.exs | OK |
| runbook contains `Bad credentials`, `RELEASE_PLEASE_TOKEN`, `0.3.1` | OK |
| ledger contains `Bad credentials`, `28399407429` | OK |
| superseded "PR #40 was the 0.3.2" framing absent from runbook | OK (refuted) |

## Deviations from Plan

None — plan executed exactly as written. Recommended research option (c) was adopted for D-08; no auto-fixes (Rules 1–3) or architectural decisions (Rule 4) were triggered. No authentication gates occurred.

## Scope Boundaries Honored

- D-08 kept tightly scoped: only the install-smoke shell-out line changed; the exact-SHA gate, hex-index wait, Phoenix-archive install, and MinIO setup in `public_smoke.sh` were untouched. JUnit was NOT disabled for the normal CI suite.
- No post-publish "0.3.2 is now live" truth edits to PROJECT.md / MILESTONES / RETROSPECTIVE were written here — that is plan 113-04 (D-12). The RELEASE-TRAIN root-cause row states "Root-caused + guarded" (historical fact); the matching "0.3.2 publish + public verify — Pass" ledger row is deliberately deferred to plan 04.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file-access patterns, or schema changes introduced. T-113-07 and T-113-08 mitigations (the junit hardening and the verified-correct recorded chain) were both implemented.

## Commits

- `d87b079` — fix(113-03): harden public_smoke junit write path so abnormal exits stay legible (D-08)
- `a443b46` — docs(113-03): record corrected stuck-release root cause in runbook + ledger (D-07)

## Self-Check: PASSED

- FOUND: `.planning/phases/113-evaluation-baseline-release-hygiene/113-03-SUMMARY.md`
- FOUND: `scripts/public_smoke.sh`
- FOUND commit: `d87b079`
- FOUND commit: `a443b46`
