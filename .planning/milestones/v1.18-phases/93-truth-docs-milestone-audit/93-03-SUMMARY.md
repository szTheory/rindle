---
phase: 93-truth-docs-milestone-audit
plan: 03
subsystem: docs
tags: [hexdocs, ex_doc, admin-console, guides, readme]

requires:
  - phase: 89-console-read-surfaces
    provides: Rindle.Admin.Router.rindle_admin/2 macro, mount/auth/asset contract
  - phase: 90-console-ops-actions
    provides: owner erasure, batch erasure, lifecycle repair, variant regen, quarantine triage actions
provides:
  - guides/admin_console.md adopter-facing console how-to
  - mix.exs docs/extras wiring (auto-grouped under Guides) + Admin Console module group
  - README Admin Console mention + admin_console.html link
affects: [milestone-audit, hexdocs, truth-07]

tech-stack:
  added: []
  patterns:
    - "Adopter how-to guides mirror streaming_providers.md / storage_gcs.md voice and section rhythm"
    - "Internal read modules (Rindle.Admin.Queries) stay out of public-API framing and module groups"

key-files:
  created:
    - guides/admin_console.md
  modified:
    - mix.exs
    - README.md

key-decisions:
  - "Documented the console as host-authenticated with a production refusal rule (non-empty :on_mount OR auth_guarded?: true; allow_unauthenticated? dev/test-only) to mitigate misconfiguration disclosure (T-93-03)."
  - "Kept Rindle.Admin.Queries out of the guide's public-API framing and out of mix.exs public module groups; only Rindle.Admin.Router is grouped (T-93-04)."

patterns-established:
  - "New guides land in mix.exs extras and auto-fall into the Guides group via the existing extras regex; no groups_for_extras change needed."

requirements-completed: [TRUTH-07]

duration: 4min
completed: 2026-06-13
---

# Phase 93 Plan 03: Admin Console Guide & HexDocs Wiring Summary

**Adopter-facing `guides/admin_console.md` authored and wired into HexDocs extras (Guides group) with an honest README mention, closing the affirmative half of TRUTH-07 — HexDocs readers now discover the mountable console.**

## Performance

- **Duration:** ~4 min
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- Authored `guides/admin_console.md` (212 lines): present-tense adopter how-to covering what the console is, the optional `phoenix_live_view` dependency, mounting via `Rindle.Admin.Router.rindle_admin/2`, the production refusal rule, the 8 console pages, operator actions (typed confirmation, reused facade verbs, no new lifecycle semantics), self-contained assets/CSP, optional-dependency compile-away, and the Cohort try-it pointer at `/admin/rindle`.
- Wired the guide into `mix.exs` `docs/0` `extras` (auto-grouped under Guides) and added an `Admin Console` module group scoped to `Rindle.Admin.Router` only.
- Added an honest "Admin Console (optional)" section and an `[Admin Console](admin_console.html)` link in the README "Next Reads" list.
- Verified `mix docs` generates `doc/admin_console.html`.

## Task Commits

1. **Task 1: Author guides/admin_console.md (adopter how-to)** - `599f4dd` (docs)
2. **Task 2: Wire the guide into mix.exs extras and add the README mention** - `f2840b0` (docs)

## Files Created/Modified

- `guides/admin_console.md` - New adopter how-to for the mountable admin console (mount, auth + production refusal, 8 pages, actions, assets/CSP, optional-dep, Cohort demo).
- `mix.exs` - Added `guides/admin_console.md` to docs extras; added `Admin Console` module group for `Rindle.Admin.Router`.
- `README.md` - Added Admin Console (optional) section and an `admin_console.html` link in Next Reads.

## Decisions Made

- Documented the production refusal rule plainly (non-empty `:on_mount` OR `auth_guarded?: true`; `allow_unauthenticated?` dev/test-only and rejected in prod) so adopters do not deploy an unauthenticated privileged console — mitigates threat T-93-03.
- Kept `Rindle.Admin.Queries` framed only as an internal read detail (no facade entrypoint) and out of mix.exs public module groups; only `Rindle.Admin.Router` is grouped — mitigates threat T-93-04.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `doc/` is gitignored (generated output), so only the two source files (`mix.exs`, `README.md`) were committed in Task 2.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TRUTH-07 affirmative docs half is complete: the console guide is HexDocs-discoverable and README-linked.
- Ready for the remaining phase 93 plan (plan 04 of 4) — milestone audit.

## Self-Check: PASSED

All created/modified files exist (guides/admin_console.md, mix.exs, README.md, 93-03-SUMMARY.md) and both task commits exist (599f4dd, f2840b0).

---
*Phase: 93-truth-docs-milestone-audit*
*Completed: 2026-06-13*
