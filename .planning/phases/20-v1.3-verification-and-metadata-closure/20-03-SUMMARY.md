---
phase: 20-v1.3-verification-and-metadata-closure
plan: 03
subsystem: docs
tags: [readme, getting-started, docs-parity, phase-19-helpers, bang-variants, onboarding-prose, td-19]

requires:
  - phase: 19-convenience-api-additions
    provides: "Eight public symbols (Rindle.attachment_for/2,3, Rindle.ready_variants_for/1, attach!/4, detach!/3, upload!/3, url!/3, variant_url!/4) plus Rindle.Error exception now taught in onboarding prose"
  - phase: 17-api-surface-boundary-audit
    provides: "Rindle.Error boundary allowlist (D-01) referenced in the new prose's raise contract"
provides:
  - "README.md teaches Rindle.attachment_for/2,3 + Rindle.ready_variants_for/1 + 5 bangs in a new section between first-run and Next Reads"
  - "guides/getting_started.md sections 8 and 9 teach the same eight symbols with the canonical-deep-guide tone"
  - "docs_parity_test.exs gates symbol presence so future regressions are caught at CI time"
  - "TD-19 (helpers discoverable only via hexdocs Facade group sidebar) closed in code"
affects:
  - milestone-audit-rerun
  - phase-21
  - future-onboarding-edits

tech-stack:
  added: []
  patterns:
    - "Atomic single-commit-per-plan onboarding-prose insertion (README + guide + parity test in one docs commit)"
    - "Symbol-presence parity test gating onboarding docs (extends Phase 17/18 pattern)"

key-files:
  created: []
  modified:
    - README.md
    - guides/getting_started.md
    - test/install_smoke/docs_parity_test.exs

key-decisions:
  - "README prose stays terse (Phoenix-controller example + brief contract surfacing); guide prose goes deeper with REPLACE-semantics call-out, both helpers' tie-break + filter rules, and an explicit rescue example for Rindle.Error"
  - "All eight symbols + 'Rindle.Error' literal asserted in BOTH onboarding docs by the new parity test (single test, two-doc loop matching the existing harness)"
  - "Phase 18 doctor gate re-run as a sanity-check verification step (Task 4) — onboarding-doc edits should not affect doctor scope (lib/), but documenting the gate prevents silent regression"

patterns-established:
  - "Canonical onboarding-prose pair: README has the brief teaching block; guides/getting_started.md carries the deeper explanation with the same example flow but more prose around opt semantics, filter behavior, and rescue patterns"
  - "Parity test extension: new tests follow the existing `for doc <- [readme, guide]` two-doc loop; new symbol assertions group by API requirement (API-09/10/11) with a final boundary-contract assertion"

requirements-completed: []

duration: 5min
completed: 2026-05-01
---

# Phase 20 Plan 03: Onboarding Prose for Phase 19 Helpers Summary

**README.md and guides/getting_started.md teach the eight Phase 19 convenience symbols (attachment_for/2,3, ready_variants_for/1, five bangs) with the Rindle.Error raise contract surfaced; docs_parity_test.exs gates regression at 5/5 GREEN.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-01T20:13:00Z
- **Completed:** 2026-05-01T20:15:28Z
- **Tasks:** 5
- **Files modified:** 3

## Accomplishments

- README.md grew by 65 lines: new `## After First Run: Querying Attachments and Variants` section between the existing first-run section (L86-122) and `## Next Reads`, plus a `### Bang Variants` subsection covering `attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4` with the `raises Rindle.Error` contract surfaced inline
- guides/getting_started.md grew by 89 lines: new `## 8. Querying Attachments and Variants` (deeper teaching of the two read helpers, including REPLACE-semantics for `:preload`, struct/binary acceptance, and Repo ownership inheritance) and `## 9. Bang Variants` (parallel teaching with an explicit `try/rescue` example for the `Rindle.Error` action/reason pattern)
- test/install_smoke/docs_parity_test.exs grew by 21 lines: new `test "README and getting-started guide teach Phase 19 convenience helpers and bangs"` asserting all eight symbol literals plus `Rindle.Error` in BOTH README.md and guides/getting_started.md
- TD-19 from `.planning/v1.3-MILESTONE-AUDIT.md` closed in code: helpers were previously discoverable only via the hexdocs Facade group sidebar — now first-class first-run-path content
- Phase 18 doctor gate re-verified at 100% doc / 100% moduledoc / 100% spec coverage across 34 modules (no regression)
- Phase 17 + 19 boundary tests still GREEN (no facade or boundary changes — pure prose + one new test)

## Task Commits

Single atomic commit per plan (per D-16 atomic-commit discipline). Tasks 1-4 were read/edit/verify steps; Task 5 staged and committed all three file changes:

1. **Task 1: Insert 'After First Run' + 'Bang Variants' sections into README.md** — included in `3e7df0b` (docs)
2. **Task 2: Insert sections 8 and 9 into guides/getting_started.md** — included in `3e7df0b` (docs)
3. **Task 3: Extend docs_parity_test.exs with 8-symbol parity test** — included in `3e7df0b` (docs); 5 tests, 0 failures
4. **Task 4: Doctor gate sanity check** — `mix doctor --full --raise` exit 0 (no commit; verification only)
5. **Task 5: Atomic docs(20) commit** — `3e7df0b` (docs)

**Plan-shipping commit:** `3e7df0b docs(20): teach Phase 19 helpers (attachment_for, ready_variants_for, bangs) in onboarding prose`

## Files Created/Modified

- `README.md` — +65 lines. New `## After First Run: Querying Attachments and Variants` section with a Phoenix-controller `show/2` example, function-by-function teaching of `Rindle.attachment_for/2,3` and `Rindle.ready_variants_for/1`, then a `### Bang Variants` subsection with copy-pasteable raise sites for each of the five bangs and pointer to non-bang twins for user-facing flows.
- `guides/getting_started.md` — +89 lines. New `## 8. Querying Attachments and Variants` with deeper teaching (REPLACE-semantics, struct-or-binary acceptance, Repo ownership note) and `## 9. Bang Variants` with the same five raise-contract examples plus a `try/rescue Rindle.Error` example showing `:action` pattern-matching.
- `test/install_smoke/docs_parity_test.exs` — +21 lines. New 4th test (now 5 tests total) asserting `Rindle.attachment_for`, `Rindle.ready_variants_for`, `Rindle.attach!`, `Rindle.detach!`, `Rindle.upload!`, `Rindle.url!`, `Rindle.variant_url!`, and `Rindle.Error` are all present in BOTH README.md and guides/getting_started.md.

## Decisions Made

- **README vs. guide prose split:** Kept README brief and copy-pasteable (single example block, terse prose between calls). Guide goes deeper — explicit REPLACE-semantics call-out for `:preload`, explicit struct-or-binary handling note for `ready_variants_for/1`, and an explicit `try/rescue` example for `Rindle.Error` action/reason pattern-matching. This honors the README/guide split established earlier ("README.md is the narrow quickstart. guides/getting_started.md is the canonical deep adopter guide").
- **`Rindle.Error` contract surfacing:** Surfaced once in README (`raises Rindle.Error on generic failures`) and twice in the guide (in section 9 prose plus as a typed exception with documented `:action` (atom) and `:reason` (term) fields, plus a rescue example). Sufficient discovery without prose bloat.
- **Single docs(20) commit:** Per D-16 atomic-commit discipline. Three files staged together, one commit, working tree clean post-commit.
- **Doctor gate re-verified as Task 4:** Onboarding-doc edits should not affect `mix doctor` (which scopes to `lib/`), but explicit re-verification prevents silent regression of the Phase 18 100/100/100 gate.

## Deviations from Plan

None — plan executed exactly as written.

All five tasks completed in sequence:
- Task 1 verification (10-pattern grep + post-edit confirmation): pass
- Task 2 verification (12-pattern grep including section-numbering anchors): pass
- Task 3 verification (`mix test test/install_smoke/docs_parity_test.exs`): 5 tests, 0 failures
- Task 4 verification (`mix doctor --full --raise`): exit 0 with 100/100/100 across 34 modules
- Task 5 verification (`git show HEAD --stat`): 3 files changed, 175 insertions(+); working tree clean post-commit

No anchors had shifted from the plan's L86 / L124 / L197 / L212 / L214 references — Edits matched on first try with surrounding-context `old_string` patterns rather than line numbers.

## Issues Encountered

None.

## User Setup Required

None — pure documentation prose plus one regression test. No environment, dashboard, or external-service configuration needed.

## Next Phase Readiness

- TD-19 closed in code: README + guide teach all eight Phase 19 helper symbols; parity test gates regression
- Phase 20 fully complete (3/3 plans shipped: 20-01 metadata retrofit, 20-02 LiveView corrective patch, 20-03 onboarding prose)
- v1.3 milestone audit re-run unblocked: G1 (15/16 VERIFICATION.md missing), G2 (16 SUMMARY frontmatter), G3 (REQUIREMENTS.md table), TD-17 (LiveView patch uncommitted), and TD-19 (Phase 19 helpers undiscoverable in onboarding) all closed in `.planning/`
- Remaining v1.3 audit items routed to Phase 21 only: G4 (hexdocs.pm reachability HTTP probe — explicitly out-of-scope per `.planning/REQUIREMENTS.md:89`)
- No blockers; no concerns

## Self-Check: PASSED

Files verified to exist:
- FOUND: README.md (modified, includes new "After First Run" section)
- FOUND: guides/getting_started.md (modified, includes sections 8 and 9)
- FOUND: test/install_smoke/docs_parity_test.exs (modified, 5 tests passing)
- FOUND: .planning/phases/20-v1.3-verification-and-metadata-closure/20-03-SUMMARY.md (this file)

Commits verified to exist:
- FOUND: 3e7df0b (docs(20): teach Phase 19 helpers... in onboarding prose)

Plans 20-01 and 20-02 commits verified unchanged at original SHAs:
- FOUND: 784f616 (20-01 metadata commit)
- FOUND: a0955d4 (20-02 LiveView corrective patch closure)
- FOUND: 15c9210 (20-02 LiveView refactor commit)
- FOUND: d8dbb36 (20-01 verification + REQUIREMENTS retrofit commit)

Test gate verified:
- FOUND: docs_parity_test.exs at 5 tests, 0 failures
- FOUND: doctor gate at 100/100/100 across 34 modules, exit 0

---

*Phase: 20-v1.3-verification-and-metadata-closure*
*Completed: 2026-05-01*
