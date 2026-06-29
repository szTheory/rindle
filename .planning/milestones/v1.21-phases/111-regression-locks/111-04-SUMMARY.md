---
phase: 111-regression-locks
plan: 04
subsystem: test-harness
tags: [meta-test, focus-visible, keyboard-modality, regression-lock, LOCK-04, quality-lane]
requires:
  - "Post-dedupe state from Plan 03: single exported focusVisibly(page, locator) helper in admin-polish.js"
  - "admin-polish.js call-form count == 1 (helper only); admin-gallery-check.mjs call-form count == 0"
provides:
  - "Merge-blocking ExUnit lock Rindle.FocusVisibleModalityGuardTest asserting the Tab-first modality invariant"
  - "Count-based dual-assert (admin-polish.js call-form == 1, gallery == 0) that REDs on a future 4th raw copy in EITHER file"
  - "Tab-before-focus ordering assertion inside the focusVisibly helper"
affects:
  - "test/focus_visible_modality_guard_test.exs"
tech-stack:
  added: []
  patterns:
    - "Glob/read harnesses + count CODE call-form (regex built at runtime) instead of bare substring — immune to comment occurrences (T-111-09)"
    - "Index-order assertion (:binary.match + Regex.run return: :index) to enforce Tab-press-before-focus inside the helper"
    - "assert files != [] anti-vacuous guard mirroring async_safety_guard_test.exs:59; SHIPPED-artifacts-only moduledoc (no .planning/ read)"
key-files:
  created:
    - "test/focus_visible_modality_guard_test.exs"
  modified: []
decisions:
  - "Test A matches the CODE call-form (not the bare `focusVisible: true` substring) for fv_idx, because the bare substring appears in comments at admin-polish.js:112 (before the Tab press at :125) which would make the order assertion wrong; the call-form first appears at :129 (after Tab), so call-form indexing is both correct and comment-immune"
  - "Call-form regex assembled from fragments at runtime so the bare prose literal is NOT written as a standalone grep-able token in this test file (defensive vs any future literal-scanning sibling)"
  - "Count-based dual-assert (admin-polish.js == 1, gallery == 0) chosen over region-scoping the helper body — simpler, stronger, catches a 4th copy in EITHER file (RESEARCH Open Q1, D-03)"
metrics:
  duration: "8 min"
  completed: "2026-06-28"
  tasks: 1
  files: 1
status: complete
---

# Phase 111 Plan 04: LOCK-04 focus-visible modality guard meta-test — Summary

Shipped `Rindle.FocusVisibleModalityGuardTest` (`test/focus_visible_modality_guard_test.exs`), a
merge-blocking ExUnit meta-test that locks the Plan 03 dedupe. It asserts the POST-DEDUPE modality
invariant: (1) the shared `focusVisibly` helper presses `Tab` before the programmatic focus
call-form, and (2) the raw `focus({ focusVisible: true })` call-form lives in exactly one place —
counting `admin-polish.js == 1` (inside the helper) and `admin-gallery-check.mjs == 0`. A future
fourth focus check that copies the raw modality call (without Tab, without the helper) now fails CI.

## What Was Built

A two-test guard riding the default suite / merge-blocking `quality` lane (`async: true`, no exclude
tag), mirroring the house `async_safety_guard_test.exs` / `ci_lane_split_test.exs` idioms (glob +
`assert files != []` anti-vacuous guard + sorted file:line offender failure messages +
SHIPPED-artifacts-only moduledoc).

- **Test A — "the shared focusVisibly helper presses Tab before the programmatic focus":** reads
  `admin-polish.js`, asserts it defines `focusVisibly` (regex tolerant of `function focusVisibly` or
  `focusVisibly = (async )?(`), then index-order asserts that the `keyboard.press("Tab")` substring
  precedes the focus CALL-FORM. Uses `:binary.match(...) |> elem(0)` for the Tab token and
  `Regex.run(call_form_regex(), helper, return: :index)` for the call-form. Both raise / fail loudly
  if the token is absent → REDs if the helper drops the Tab press OR drops the focus.

- **Test B — "no harness calls the raw focusVisible call-form outside the shared helper":** builds the
  harness file list, `assert files != []` (anti-vacuous, T-111-10 / RESEARCH Pitfall 5), then uses the
  COUNT-BASED mechanic over the CODE call-form: `admin-polish.js` must have EXACTLY ONE occurrence and
  `admin-gallery-check.mjs` must have ZERO. Emits a sorted `file:line` offender list on deviation
  (mirrors the analog's `failure_message` style). The count pair catches a future 4th copy in EITHER
  file (T-111-11).

### The call-form vs bare-substring distinction (the load-bearing design choice)

The bare token `focusVisible: true` appears in backtick-wrapped PROSE COMMENTS
(`admin-polish.js:112` and `:449`, `admin-gallery-check.mjs:170`). A bare-substring count would see
those and assert a wrong number — either always-red or, worse, masking a real bypass (T-111-09). The
guard counts the CODE CALL-FORM instead — the `el.focus({ focusVisible: true })` expression — which
appears ONLY at real call sites. The call-form regex (`focus(` + `{` + the focusVisible option +
`}` + `)`, flexible inner spacing) is assembled from fragments at runtime so the bare prose literal
is not written as a standalone grep-able token in this file.

Live verification of the distinction:

| File | bare substring count | CODE call-form count (asserted) |
| ---- | -------------------- | ------------------------------- |
| admin-polish.js | 3 (2 comments + 1 call site) | 1 |
| admin-gallery-check.mjs | 1 (1 comment) | 0 |

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | LOCK-04 — focus-visible modality guard meta-test (count-based dual-assert) | a319fca | test/focus_visible_modality_guard_test.exs |

## Verification

- `mix test test/focus_visible_modality_guard_test.exs` → **2 tests, 0 failures** on the post-Plan-03
  deduped state.
- **Anti-theater RED proof 1 (Test B):** temporarily appended a raw `el.focus({ focusVisible: true })`
  to `admin-gallery-check.mjs` → Test B RED ("Expected admin-gallery-check.mjs to contain EXACTLY 0
  ... found 1"); reverted (`git status` clean, call-form count back to 0).
- **Anti-theater RED proof 2 (Test A):** temporarily reordered the helper so the focus precedes the
  Tab press → Test A RED ("focusVisibly must press Tab (idx 6003) BEFORE the focusVisible focus
  call-form (idx 5930)"); reverted.
- **Comment-immunity confirmed:** the bare-substring comment occurrences (admin-polish.js :112/:449,
  gallery :170) do NOT trip the call-form count — call-form counts are 1 / 0 while bare counts are
  3 / 1 (the whole point of the call-form mechanic, T-111-09).
- **Anti-vacuous:** `assert files != []` present (Test B).
- Module is `async: true`, no exclude tag (default suite → merge-blocking `quality` lane). Reads only
  SHIPPED `examples/` + `brandbook/` paths — never a `.planning/` path, so the LOCK-05
  planning-path-hygiene sibling stays green (verified: the only `.planning` mention is prose in the
  moduledoc, not a `File.read!`/`File.exists?`/`Path.expand` over a `.planning` path).
- Zero `lib/` change; the harness JS files are unchanged (the RED proofs were reverted, `git status`
  shows only the new test file). No semver impact, no new attack surface, no OBS-02 literal-drift risk
  to existing meta-tests.

## Deviations from Plan

None — plan executed exactly as written.

One in-plan resolution worth recording (explicitly anticipated by the plan's counting caveat, not a
deviation): Test A's `fv_idx` matches the CODE call-form rather than the bare `focusVisible: true`
substring the RESEARCH Pattern-2 sketch used. The bare substring first appears in a comment at
`admin-polish.js:112` — BEFORE the Tab press at `:125` — so a bare-substring `fv_idx` would compute a
position earlier than the Tab press and make the order assertion incorrect. The call-form first
appears at `:129` (after Tab), so call-form indexing is both correct for the ordering check and
immune to the comment occurrences. This is the same call-form-over-bare-substring mechanic the plan
mandates for Test B's count.

## Known Stubs

None.

## Threat Flags

None. This is an internal meta-test over already-shipped JS harnesses (demo + brandbook, NOT
adopter-facing `lib/`). Threat register dispositions satisfied: T-111-09 (counts the CODE call-form,
immune to the comment occurrences — verified 1/0 vs bare 3/1), T-111-10 (`assert files != []` so an
empty/mis-rooted harness list fails loudly), T-111-11 (count-based dual-assert REDs on a future 4th
raw copy in EITHER file — proven via RED proof 1). No new endpoint, secret, package, schema, or
trust-boundary surface.

## Self-Check: PASSED

- Created file exists: `test/focus_visible_modality_guard_test.exs` — FOUND.
- Commit exists: `a319fca` — FOUND (`test(111-04): lock focus-visible modality dedupe (LOCK-04)`).
- `mix test test/focus_visible_modality_guard_test.exs` — 2 tests, 0 failures.
