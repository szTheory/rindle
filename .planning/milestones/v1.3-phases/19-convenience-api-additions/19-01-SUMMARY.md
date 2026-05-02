---
phase: 19-convenience-api-additions
plan: 01
subsystem: testing
tags: [elixir, exunit, tdd, red-commit, mox, ecto]

# Dependency graph
requires:
  - phase: 17-api-surface-boundary-audit
    provides: api_surface_boundary_test.exs @public_modules allowlist (Rindle.Error appended here)
  - phase: 18-doc-coverage
    provides: locked public surface (no further surface drift before 19-02)
provides:
  - test/rindle/convenience_api_test.exs — failing harness covering D-23 test matrix and D-24 message branches
  - @public_modules allowlist updated for Rindle.Error (D-11)
  - RED signal that Plan 19-02 will turn GREEN
affects:
  - 19-02 (GREEN implementation must satisfy this exact test suite)
  - any future phase modifying convenience-API behavior or Rindle.Error message contract

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Phase 17 P01 / Phase 18 P01 RED-then-GREEN rhythm reproduced for Phase 19
    - struct!/2 runtime-resolution pattern for referencing not-yet-existing modules in tests without compile-time breakage

key-files:
  created:
    - test/rindle/convenience_api_test.exs
  modified:
    - test/rindle/api_surface_boundary_test.exs

key-decisions:
  - "Use struct!(Rindle.Error, ...) instead of %Rindle.Error{} struct literals so the test file compiles before Rindle.Error exists — corrects a factual error in the plan's compile-time reasoning while preserving D-11/D-24 intent and all grep-based acceptance criteria."

patterns-established:
  - "Forward-reference test pattern: when a test must reference a module that does not yet exist, prefer struct!/2 + bare-module Module.fun(...) calls over struct literals (%Mod{...}) — struct literals demand compile-time resolution; struct!/2 defers to runtime where the desired UndefinedFunctionError is the RED signal."

requirements-completed: []  # API-09 / API-10 / API-11 are partially advanced (RED only); they remain open until Plan 19-02 lands GREEN. Do NOT mark complete here.

# Metrics
duration: 3min
completed: 2026-05-01
---

# Phase 19 Plan 01: Convenience API RED Harness Summary

**RED-only ExUnit harness for 8 new convenience facade entrypoints + Rindle.Error.message/1 — 22 failing tests, all referencing functions/modules that do not exist on master yet, set up to flip GREEN when Plan 19-02 ships the implementation.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-01T16:41:43Z
- **Completed:** 2026-05-01T16:44:54Z
- **Tasks:** 3 (19-01-01, 19-01-02, 19-01-03)
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **9 describe blocks, 22 tests** covering the full D-23 / D-24 matrix:
  - `attachment_for/2` (3 tests), `attachment_for/3` (2)
  - `ready_variants_for/1` (5 — empty list, state filter, ordering, struct + binary id forms)
  - `Rindle.Error.message/1` (3 — `:not_found`, `{:quarantine, _}`, fallback inspect)
  - `attach!/4` (2), `detach!/3` (2), `upload!/3` (2), `url!/3` (2), `variant_url!/4` (1)
- **`Rindle.Error` added to `@public_modules` allowlist** at line 6, alphabetically positioned between `Rindle,` (line 5) and `Rindle.Profile,` (line 7) per D-11 / Pattern Map.
- **RED contract is contractually visible:** `mix test test/rindle/convenience_api_test.exs` exits 2 with all 8 expected symbol references in the failure output (`Rindle.attachment_for`, `Rindle.ready_variants_for`, `Rindle.attach!`, `Rindle.detach!`, `Rindle.upload!`, `Rindle.url!`, `Rindle.variant_url!`, `Rindle.Error`). Boundary test exits 2 with `Rindle.Error must be loadable` — D-11 trip-wire ready to flip GREEN.
- **No collateral damage:** `mix test test/rindle/attach_detach_test.exs` still exits 0; `mix compile --warnings-as-errors` exits 0; `mix format --check-formatted` exits 0.

## Task Commits

Per plan 19-01 design, all three tasks land as a SINGLE conventional-commit RED commit (the plan's Task 19-01-03 explicitly batches stage + commit for both target files together):

1. **Tasks 19-01-01 + 19-01-02 + 19-01-03 (combined RED commit)** — `ec8c716` (`test(19-01): add RED test harness for convenience API + boundary allowlist`)

No separate per-task commits were made because the plan body specifies a single combined RED commit; splitting it would have produced an intermediate compile-passing-but-test-RED state that is not what the plan describes.

## Files Created/Modified

- `test/rindle/convenience_api_test.exs` (created, 301 lines) — failing harness for `Rindle.attachment_for/2,3`, `Rindle.ready_variants_for/1`, `Rindle.{attach,detach,upload,url,variant_url}!`, and `Rindle.Error.message/1`. Boilerplate mirrors `test/rindle/attach_detach_test.exs` (`use Rindle.DataCase, async: false` + `use Oban.Testing, repo: Rindle.Repo` + `import Mox` + `setup :set_mox_from_context` + `setup :verify_on_exit!` + `TestProfile` + `User` + MediaAsset insert).
- `test/rindle/api_surface_boundary_test.exs` (modified, +1 line) — `Rindle.Error,` inserted at line 6 of `@public_modules`.

## Decisions Made

- **`struct!/2` runtime resolution over struct literal `%Rindle.Error{...}`** — the plan's "Key implementation notes" claimed Elixir resolves struct names lazily at compile time, but in fact `%Rindle.Error{action: ..., reason: ...}` literals require the struct to be loaded at compile time and emit a `Rindle.Error.__struct__/1 is undefined` compile error before any test runs. Replaced the three struct-literal lines in the `Rindle.Error.message/1` describe block with `struct!(Rindle.Error, action: ..., reason: ...)` so the file compiles cleanly and the runtime call still raises `UndefinedFunctionError` at test time — preserving the D-11 / D-24 intent and every grep-based acceptance criterion (15 `Rindle.Error` mentions, 3 `assert_raise Rindle.Error` patterns).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced `%Rindle.Error{...}` struct literals with `struct!(Rindle.Error, ...)`**

- **Found during:** Task 19-01-02 (running the new test file under `mix test`)
- **Issue:** The plan's verbatim test body used `%Rindle.Error{action: :attach, reason: :not_found}` in three places. The plan author asserted (line ~489 of 19-01-PLAN.md) that this would compile cleanly because "Elixir resolves struct names lazily at compile time only when defined inline." This is factually wrong about Elixir: struct literals (`%Module{...}`) require the target module to be loaded at compile time, otherwise the compiler emits `Rindle.Error.__struct__/1 is undefined ... cannot expand struct Rindle.Error`. Without a fix, `mix test test/rindle/convenience_api_test.exs` would have failed on a CompileError before any test even registered, blocking the test runner from enumerating the test cases that actually exercise the `assert_raise Rindle.Error` runtime contracts.
- **Fix:** Changed three lines in the `describe "Rindle.Error.message/1"` block from `err = %Rindle.Error{...}` to `err = struct!(Rindle.Error, ...)`. `struct!/2` is a kernel macro that defers struct-module resolution to runtime, so the file compiles before `Rindle.Error` exists and the runtime call still raises `UndefinedFunctionError: function Rindle.Error.__struct__/1 is undefined` — which is the RED signal the plan asks for.
- **Files modified:** `test/rindle/convenience_api_test.exs` (3 lines, in the `describe "Rindle.Error.message/1"` block) plus a 4-line comment explaining the choice.
- **Verification:**
  - `mix compile --warnings-as-errors` exits 0 (production code unaffected)
  - `mix test test/rindle/convenience_api_test.exs` exits 2 with `22 tests, 22 failures` — every failure references one of the 8 not-yet-existing symbols (verified via `grep -qE "Rindle\.(Error|attachment_for|ready_variants_for|attach!|detach!|upload!|url!|variant_url!)"`)
  - All grep-based acceptance criteria from the plan (line counts, describe-block counts, function-reference counts, `assert_raise Rindle.Error` count, `Rindle.Error` total count) still pass after the fix
- **Committed in:** `ec8c716` (the single Plan 19-01 RED commit; the fix is part of the test file as committed)

**2. [Rule 1 - Bug] Re-formatted `Path.join` call in `upload!/3` happy-path test**

- **Found during:** Task 19-01-03 (running `mix format --check-formatted`)
- **Issue:** The plan's verbatim test body had a `Path.join(System.tmp_dir!(), "rindle_test_upload_#{System.unique_integer([:positive])}.jpg")` call on a single line that exceeded the 98-character formatter line limit. `mix format --check-formatted` exited 1.
- **Fix:** Ran `mix format test/rindle/convenience_api_test.exs` per the plan's explicit Task 19-01-03 instruction ("if it fails, run `mix format ...` and re-verify"). Formatter wrapped the call across 4 lines using its standard multi-arg form.
- **Files modified:** `test/rindle/convenience_api_test.exs` (formatter-only diff, no semantic change)
- **Verification:** `mix format --check-formatted` exits 0 after the reformat.
- **Committed in:** `ec8c716`

---

**Total deviations:** 2 auto-fixed (Rule 1 — both bugs in the literal plan body). Test file final size: 301 lines (≥250 minimum, +51 over the floor).

**Impact on plan:** Both fixes are local to the test file body and preserve every D-23/D-24 test case the plan prescribed. No new test cases were added or removed. The 9-describe-block structure is intact. All grep-based acceptance criteria pass. Plan 19-02 implementation contract is unchanged: ship `Rindle.Error` as a defexception/struct module + the 8 functions, and these 22 tests will flip GREEN.

## Issues Encountered

- **Compile-time vs runtime RED confusion in plan body:** the plan's "Key implementation notes" included a wrong claim about Elixir struct resolution. Caught by running the test file (which was the plan's own verification step) and fixed via `struct!/2` (Rule 1). Documented as a deviation; the plan body itself does not need to be edited because the deviation is fully covered in this SUMMARY.
- **No formatting auto-run in plan body:** the plan acceptance criteria require `mix format --check-formatted` exit 0, but the plan's verbatim test body had one line that the formatter wanted re-wrapped. The plan anticipated this in its Task 19-01-03 instructions ("if it fails, run `mix format ... ` and re-verify"), and that workflow ran cleanly.

## Stub Tracking

None — this plan is test-only. No production stubs introduced.

## Threat Flags

None. Plan 19-01 introduces no new external input handling, no new HTTP/file I/O, no new authn/authz path. Threat register T-19-01..T-19-06 all dispositioned `accept`; nothing surfaced during execution that warrants a new threat flag.

## TDD Gate Compliance

This plan is the RED gate for Phase 19 (parent plan `type: execute`, but functionally RED-only per D-25 and the plan's own success criteria #1). The corresponding GREEN commit will land in Plan 19-02. After Plan 19-02 lands, verify in `git log --oneline`:

1. `test(19-01)` commit (RED gate) — **landed** at `ec8c716`
2. `feat(19-02)` commit (GREEN gate) — **pending Plan 19-02**

If after 19-02 lands either gate is missing, treat as a TDD-gate compliance failure.

## Next Phase / Plan Readiness

**Plan 19-02 (GREEN trigger) — must implement in this single plan:**

1. **`Rindle.Error` module** (`lib/rindle/error.ex`)
   - `defexception [:action, :reason]` (or equivalent struct + Exception protocol implementation)
   - `message/1` clauses:
     - `%__MODULE__{action: action, reason: :not_found}` → `"could not #{action}: not found"`
     - `%__MODULE__{action: action, reason: {:quarantine, why}}` → message containing `"could not #{action}"`, `"quarantined"`, and `inspect(why)`
     - fallback `%__MODULE__{action: action, reason: reason}` → message containing `"could not #{action}"` and `inspect(reason)`
   - `@moduledoc` non-false, non-`:hidden`, non-`nil` so the boundary test's `visible_module?(Rindle.Error)` passes
2. **8 facade convenience functions** on `Rindle` (`lib/rindle.ex` or its splits):
   - `attachment_for/2,3` — query `MediaAttachment` by owner_type+owner_id+slot, default `preload: [:asset]`, replace-not-merge keyword form
   - `ready_variants_for/1` — accepts `%MediaAsset{}` or binary id; filters `state == "ready"`; orders by `:name asc`; returns `[]` on no rows
   - `attach!/4` — wraps `attach/4`; unwraps `{:ok, attachment}`; raises `Rindle.Error{action: :attach}` on `{:error, _}`
   - `detach!/3` — wraps `detach/3`; unwraps bare `:ok` (NOT `{:ok, _}` — D-15 trap); idempotent on missing attachment
   - `upload!/3` — wraps `upload/3`; unwraps `{:ok, asset}`; re-raises storage adapter exceptions with fresh stacktrace (D-13)
   - `url!/3` — wraps `url/3`; unwraps `{:ok, url}`; raises `Rindle.Error{action: :url}` on `{:error, _}`
   - `variant_url!/4` — wraps `variant_url/4`; raises `Rindle.Error{action: :variant_url}` on `{:error, _}`
3. **`mix.exs` ExDoc group entry** for `Rindle.Error` (so the boundary test sees a non-hidden `:moduledoc`).
4. **CHANGELOG.md** entry under the next 0.1.x prerelease section listing the 8 new functions and `Rindle.Error`.

**Verification after 19-02:**
- `mix test test/rindle/convenience_api_test.exs` → exit 0, 22 tests pass
- `mix test test/rindle/api_surface_boundary_test.exs` → exit 0, 8 tests pass (D-03 reconciliation now sees `Rindle.Error` as `visible_module?`)
- `mix test` whole-suite → exit 0
- `mix format --check-formatted` → exit 0
- `mix compile --warnings-as-errors` → exit 0
- `mix dialyzer` → no new warnings on the 8 new public functions or `Rindle.Error`

No blockers. Plan 19-02 has everything it needs to start.

---
*Phase: 19-convenience-api-additions*
*Plan: 01 (RED-only failing-test harness)*
*Completed: 2026-05-01*

## Self-Check: PASSED

- File exists: `test/rindle/convenience_api_test.exs` ✓
- File exists: `test/rindle/api_surface_boundary_test.exs` ✓
- File exists: `.planning/phases/19-convenience-api-additions/19-01-SUMMARY.md` ✓
- Commit exists: `ec8c716` (test(19-01): add RED test harness for convenience API + boundary allowlist) ✓
- Plan-level verification (all 9 checks from `<verification>` block):
  1. `git log -1 --pretty=format:"%s"` matches `^test(19-01):` ✓
  2. `wc -l test/rindle/convenience_api_test.exs` ≥ 250 → **301** ✓
  3. `grep -c "describe " test/rindle/convenience_api_test.exs` = 9 ✓
  4. `awk 'NR==6'` of boundary test contains `Rindle.Error,` ✓
  5. `mix compile --warnings-as-errors` exits 0 ✓
  6. `mix test test/rindle/convenience_api_test.exs` exits NON-ZERO (2) and grep matches the 8 expected symbols ✓
  7. `mix test test/rindle/api_surface_boundary_test.exs` exits NON-ZERO (2) and output mentions `Rindle.Error must be loadable` ✓
  8. `mix format --check-formatted` exits 0 ✓
  9. `mix test test/rindle/attach_detach_test.exs` exits 0 (existing tests undisturbed) ✓
