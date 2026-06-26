---
phase: 93-truth-docs-milestone-audit
plan: 01
subsystem: docs
tags: [moduledoc, admin-console, truth-parity, hexdocs, user-flows]

# Dependency graph
requires:
  - phase: 89-console-read-surfaces
    provides: Rindle.Admin.Router.rindle_admin/2 macro + Rindle.Admin.Queries internal read models
provides:
  - Truthful Rindle facade @moduledoc that no longer denies an admin UI and points to rindle_admin/2 + guides/admin_console.md
  - operations.md and troubleshooting.md that affirm the mountable console while preserving the "no auto-remediation" truth
  - user_flows.md with admin UI removed from both the deferred and out-of-scope lists, force-delete + cron erasure deferrals intact
affects: [93-truth-docs-milestone-audit, admin_console, docs-parity-test]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Doc-only truth-parity edits: affirm shipped surface without over-claiming (host owns auth; no auto-remediation)"

key-files:
  created:
    - .planning/phases/93-truth-docs-milestone-audit/93-01-SUMMARY.md
  modified:
    - lib/rindle.ex
    - guides/operations.md
    - guides/troubleshooting.md
    - guides/user_flows.md

key-decisions:
  - "Phrased every edit to affirm the mountable console's existence while preserving the deferred force-delete + scheduler/cron erasure deferrals and the no-auto-remediation truth (avoids over-claiming per threat T-93-01)"
  - "Kept Rindle.Admin.Queries documented as internal and explicitly NOT promoted onto the Rindle facade"

patterns-established:
  - "Truth-parity doc edits link guides/admin_console.html and reference rindle_admin/2 as the only new public surface"

requirements-completed: [TRUTH-07]

# Metrics
duration: 2min
completed: 2026-06-13
---

# Phase 93 Plan 01: Truth-Docs Scope-Reversal Surfaces Summary

**Flipped the four code/guide surfaces that falsely denied the shipped admin console: the `Rindle` facade `@moduledoc`, `operations.md`, `troubleshooting.md`, and `user_flows.md` now tell the truth about `Rindle.Admin.Router.rindle_admin/2` while keeping force-delete and cron erasure deferred.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-13T06:27:21Z
- **Completed:** 2026-06-13T06:29:23Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Removed "admin UI" from the facade's negative-promise list and added a truthful pointer to the mountable console (`Rindle.Admin.Router.rindle_admin/2`) and `guides/admin_console.md`, while keeping `Rindle.Admin.Queries` documented as internal.
- Reversed the "intentionally has no dashboard" claim in both `operations.md` and `troubleshooting.md`, affirming the console while preserving the "no auto-remediation" truth (the console runs operator verbs, it never self-heals).
- Removed the admin UI from both the deferred and the deliberately-out-of-scope lists in `user_flows.md`, leaving force-delete and scheduler/cron erasure deferrals intact.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix the facade @moduledoc admin-UI denial (F1)** - `c9b3de9` (docs)
2. **Task 2: Reverse the "no dashboard" claim in operations.md and troubleshooting.md (F2, F3)** - `6eac385` (docs)
3. **Task 3: Remove admin UI from user_flows.md deferred + out-of-scope lists (F4, F5)** - `ed43721` (docs)

**Plan metadata:** committed separately with this SUMMARY + STATE/ROADMAP/REQUIREMENTS updates.

## Files Created/Modified
- `lib/rindle.ex` - Facade `@moduledoc`: dropped "admin UI" from the negative-promise list; added a truthful mountable-console pointer (`rindle_admin/2` + `guides/admin_console.md`); kept force-delete + cron erasure as unsupported and `Rindle.Admin.Queries` as internal.
- `guides/operations.md` - Replaced "intentionally has no dashboard" with a console affirmation linking `admin_console.html`; preserved "no auto-remediation".
- `guides/troubleshooting.md` - Same correction applied to the matching "no dashboard / no auto-remediation" sentence.
- `guides/user_flows.md` - Removed "Admin UI, " from the deferred list (added a console mention) and "an admin UI, " from the out-of-scope list; force-delete + cron erasure deferrals retained.

## Decisions Made
- Affirmed console existence without over-claiming: every edit preserves the "host owns auth / production refuses unsafe mounts" boundary by pointing at `guides/admin_console.md` and keeps the "no auto-remediation" truth, mitigating threat T-93-01 (adopters mis-deploying).
- Kept `Rindle.Admin.Queries` documented as internal and explicitly not promoted onto the `Rindle` facade.

## Deviations from Plan

None - plan executed exactly as written. (No package installs; doc-only edits per the threat model.)

## Issues Encountered
- `mix compile --warnings-as-errors` fails on a pre-existing, out-of-scope warning at `lib/rindle/admin/queries.ex:224` (unused private `action/4` clause). Verified pre-existing by stashing the 93-01 edit and recompiling on clean HEAD — the warning persists without my change, and `queries.ex` is outside the four files this plan edits. Plain `mix compile` succeeds and the compiled facade doc verification (no "admin ui" denial) passes. Logged to `.planning/phases/93-truth-docs-milestone-audit/deferred-items.md`; recommend a follow-up plan resolve the unused clause. Not fixed here per the SCOPE BOUNDARY rule.

## Parity-test note
The `docs_parity_test.exs` assertions that currently freeze the OLD phrasing (`operations =~ "no dashboard"`, `user_flows` contains normalized "admin ui", and the compiled facade doc) are intentionally NOT edited by this plan — Plan 04 updates the parity lock. Running that test now will fail on the changed phrasing; that is expected until Plan 04 lands.

## Next Phase Readiness
- F1–F5 corrected; the facade moduledoc and three guides no longer deny the admin console.
- Plan 04 must update `test/install_smoke/docs_parity_test.exs` to lock the new truthful phrasing (and to assert force-delete + cron erasure deferrals remain).
- Out-of-scope pre-existing `queries.ex:224` warning recorded in deferred-items for follow-up.

## Self-Check: PASSED

- Files verified present: lib/rindle.ex, guides/operations.md, guides/troubleshooting.md, guides/user_flows.md, 93-01-SUMMARY.md
- Commits verified in git log: c9b3de9, 6eac385, ed43721

---
*Phase: 93-truth-docs-milestone-audit*
*Completed: 2026-06-13*
