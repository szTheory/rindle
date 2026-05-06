---
phase: 24-domain-model-dsl-extension
plan: 01
subsystem: rindle
tags: [av, probe, metadata, backward-compat, digest]
requires:
  - phase: 23-av-foundations
    provides: FFprobe shim, boot probe, canonical adopter fixture
provides:
  - v1.3 thumb digest regression anchor for image-profile backward compatibility
  - Rindle.Probe behaviour contract with probe/1 and accepts?/1 callbacks
  - Public AV metadata sanitizer with UTF-8-safe byte truncation
affects: [24-04, 24-05, validator, probe-adapters]
tech-stack:
  added: []
  patterns: [load-bearing digest snapshot, behaviour-first probe contract, recursive metadata sanitization]
key-files:
  created:
    - test/rindle/backward_compat/v13_digest_snapshot_test.exs
    - lib/rindle/probe.ex
    - test/rindle/probe_test.exs
    - lib/rindle/av/metadata_sanitizer.ex
    - test/rindle/av/metadata_sanitizer_test.exs
  modified: []
key-decisions:
  - "Captured @v13_thumb_digest as 3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7 before any Phase 24 validator edits."
  - "Kept lib/rindle/av/probe.ex and lib/rindle/av/ffprobe.ex untouched while introducing new probe and sanitizer scaffolds."
  - "Preserved byte-accurate UTF-8 truncation semantics and corrected plan-internal test/doc contradictions instead of weakening the sanitizer implementation."
patterns-established:
  - "Backward-compat anchors for DSL changes should be committed before touching validator logic."
  - "Probe adapters will implement a small behaviour surface and layer sanitizer logic outside the FFprobe shim."
requirements-completed: [AV-02-05, AV-02-10, AV-02-11]
duration: 14min
completed: 2026-05-05
---

# Phase 24 Plan 01: Domain Model DSL Extension Summary

**Captured the v1.3 canonical `:thumb` digest, introduced the `Rindle.Probe` contract, and shipped a public AV metadata sanitizer for downstream probe adapters.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-05-05T15:14:00Z
- **Completed:** 2026-05-05T15:28:08Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Captured the load-bearing v1.3 `:thumb` digest snapshot in `test/rindle/backward_compat/v13_digest_snapshot_test.exs` before any `validator.ex` edits landed.
- Added `Rindle.Probe` with `probe/1` and `accepts?/1` callbacks plus a contract test for stub implementations.
- Added `Rindle.AV.MetadataSanitizer` with recursive sanitization, control-character stripping, and UTF-8-safe byte truncation backed by boundary tests.

## Captured Digest

- `@v13_thumb_digest`: `3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7`

## Task Commits

1. **Task 1: Capture v1.3 :thumb digest snapshot** - `b2b90fc` (`test`)
2. **Task 2: Create Rindle.Probe behaviour scaffold** - `8a368a6` (`feat`)
3. **Task 3: Create Rindle.AV.MetadataSanitizer with public sanitize/1 and truncate_to_bytes/2** - `c32e5b6` (`feat`)

## Files Created/Modified

- `test/rindle/backward_compat/v13_digest_snapshot_test.exs` - Load-bearing digest snapshot and deferred Plan 04 assertions.
- `lib/rindle/probe.ex` - Behaviour contract for probe adapters.
- `test/rindle/probe_test.exs` - Behaviour callback and dispatch contract test.
- `lib/rindle/av/metadata_sanitizer.ex` - Public recursive sanitizer and UTF-8-safe truncation helper.
- `test/rindle/av/metadata_sanitizer_test.exs` - Control-character, recursion, and byte-boundary coverage.

## Decisions Made

- `lib/rindle/profile/validator.ex`, `lib/rindle/av/ffprobe.ex`, and `lib/rindle/av/probe.ex` remained untouched throughout Wave 0.
- The canonical adopter profile fixture stayed the source of truth for the backward-compat digest anchor.
- The sanitizer kept strict byte-count semantics instead of relaxing to character-count truncation.

## Verification

- `mix test test/rindle/backward_compat/ test/rindle/probe_test.exs test/rindle/av/metadata_sanitizer_test.exs --warnings-as-errors`
- `mix compile --warnings-as-errors`
- `git diff --name-only lib/rindle/profile/validator.ex lib/rindle/av/ffprobe.ex lib/rindle/av/probe.ex` returned empty.
- `grep -rn 'String.byte_slice' lib/rindle/av/metadata_sanitizer.ex` returned no matches.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Loaded the canonical adopter fixture explicitly for digest capture**
- **Found during:** Task 1 (Capture v1.3 :thumb digest snapshot)
- **Issue:** The plan's plain `mix run -e 'IO.puts(...)'` command failed because the test-only canonical adopter module is not loaded in a normal `mix run` session.
- **Fix:** Captured the digest with `Code.require_file("test/adopter/canonical_app/profile.ex")` in the `mix run` expression.
- **Files modified:** None
- **Verification:** Captured digest `3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7`, then `mix test test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors` passed.
- **Committed in:** `b2b90fc`

**2. [Rule 1 - Bug] Corrected contradictory `truncate_to_bytes/2` expectations**
- **Found during:** Task 3 (Create Rindle.AV.MetadataSanitizer)
- **Issue:** The provided module body was byte-correct, but the plan's doctest and two `héllo` test expectations were inconsistent with actual UTF-8 byte boundaries. The module also mentioned the forbidden literal `String.byte_slice` while the acceptance criterion required zero matches.
- **Fix:** Updated the doctest and test expectations to reflect byte-accurate results (`4 -> "hél"`, `3 -> "hé"`), and rewrote the Elixir 1.17 note to avoid the forbidden literal while preserving the compatibility rationale.
- **Files modified:** `lib/rindle/av/metadata_sanitizer.ex`, `test/rindle/av/metadata_sanitizer_test.exs`
- **Verification:** `mix test test/rindle/av/metadata_sanitizer_test.exs --warnings-as-errors`, `mix compile --warnings-as-errors`, and `grep -rn 'String.byte_slice' lib/rindle/av/metadata_sanitizer.ex`.
- **Committed in:** `c32e5b6`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes were necessary to make the plan internally consistent and verifiable without expanding scope.

## Issues Encountered

- The plan output section claimed "3 new files, 0 modified", but the plan frontmatter and task list required 5 new files. Execution followed the task/file declarations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Wave 1 readiness checklist:
- Snapshot committed: yes
- Plan 04 may now begin: yes
- `validator.ex` remains untouched by Wave 0: yes
- `ffprobe.ex` remains untouched by Wave 0: yes

## Self-Check

- Summary file exists: PASS
- Task commits verified: `b2b90fc`, `8a368a6`, `c32e5b6`
- Self-Check: PASSED

---
*Phase: 24-domain-model-dsl-extension*
*Completed: 2026-05-05*
