---
phase: 107-reliability-security-dx-hardening
plan: 01
subsystem: testing
tags: [exunit, async-safety, ast-meta-test, macro-prewalk, ci, concurrency]

# Dependency graph
requires:
  - phase: 107-reliability-security-dx-hardening
    provides: RESEARCH per-file async classification (15 CLEAN / 53 GENUINELY-UNSAFE), HARD-01 guard mechanism + PATTERNS node-shapes
provides:
  - ExUnit async-safety static AST guard (inverse gate) that fails the merge-blocking suite if any async:true module uses an unsafe shared-state primitive
  - 15 RESEARCH-CLEAN test modules converted async:false -> async:true (in-runner speedup)
  - "@async_safety_allow [...] escape-hatch convention for provably-safe-but-statically-unprovable primitive usages"
affects: [future async:true conversions, CI quality lane, HARD-02, HARD-03, HARD-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AST meta-test: glob test/**/*_test.exs -> Code.string_to_quoted! -> Macro.prewalk to assert over source structure (analog to docs_parity_test.exs)"
    - "Fail-closed async-safety inverse guard with @async_safety_allow opt-out + transitive tmp-var dataflow tracking for File.* path args"

key-files:
  created:
    - test/async_safety_guard_test.exs
  modified:
    - test/rindle/profile/profile_test.exs
    - test/rindle/streaming/provider/mux/http_cancel_upload_test.exs
    - test/rindle/storage/local_test.exs
    - test/install_smoke/package_metadata_test.exs
    - test/rindle/admin/queries_test.exs (+ 14 more conversions)

key-decisions:
  - "Resolved the guard's 4 pre-existing offenders (orchestrator-approved Option A) rather than deferring: 2 GENUINE races flipped to async:false, 2 SAFE modules annotated with justified @async_safety_allow [:file_mutation]"
  - "Added a 1-line def __async_safety_allow__/0 per annotated module so mix compile --warnings-as-errors does not trip on 'attribute set but never used' (guard reads the attribute from source AST, not at runtime)"
  - "--partitions DEFERRED (D-01); guard logic NOT weakened to suppress findings (detector fixed nothing — the modules were fixed)"

patterns-established:
  - "async-safety inverse guard: a self-enforcing red gate for future async:true regressions"
  - "@async_safety_allow [:primitive] + justification comment as the documented, fail-closed escape hatch"

requirements-completed: [HARD-01]

# Metrics
duration: ~18min
completed: 2026-06-22
status: complete
---

# Phase 107 Plan 01: Async-Safety Static Guard + 15-Module async:true Conversion Summary

**An AST-walking ExUnit meta-test that red-gates any `async: true` module using an unsafe shared-state primitive, plus 15 RESEARCH-CLEAN modules flipped to `async: true` — guard GREEN against the full tree.**

## Performance

- **Duration:** ~18 min (resume; prior session built Task 1's guard)
- **Started:** 2026-06-22 (resume)
- **Completed:** 2026-06-22
- **Tasks:** 2/2
- **Files modified:** 20 (1 new guard + 4 authorized fixes + 15 conversions)

## Accomplishments
- Landed `test/async_safety_guard_test.exs` (D-02, FIRST): globs `test/**/*_test.exs`, parses each to AST, and for every `async: true` module asserts no `Application/System.put_env`, `set_mox_global`, fixed-name process, fixed-path `File` mutation, public/named ETS, `:persistent_term.put`, or `{:shared, _}` sandbox. Fail-closed with `@async_safety_allow` opt-out and transitive tmp-var dataflow tracking so per-test-unique `File.*` paths are not flagged.
- Drove the guard to GREEN by resolving its 4 pre-existing offenders (orchestrator-approved Option A) — without weakening the detector.
- Converted the 15 RESEARCH-verified-CLEAN modules `async: false` -> `async: true`; the `owner_erasure_batch_opts_test.exs` sibling pairing was preserved (only the `async: false` Integration module flipped).
- Full default suite: 3 doctests, 1160 tests, 4 skipped — the only failure is a pre-existing, out-of-scope docs-parity test (see Deviations).

## Task Commits

1. **Task 1: Land the async-safety AST meta-test guard (+ resolve 4 offenders)** - `e4e3186` (test)
2. **Task 2: Convert the 15 CLEAN modules to async:true** - `a583040` (test)

**Plan metadata:** see final docs commit below.

## Files Created/Modified
- `test/async_safety_guard_test.exs` (NEW) — AST async-safety inverse guard, itself `async: true`.
- `test/rindle/profile/profile_test.exs` — flipped to `async: false` (GENUINE `Application.put_env :signed_url_ttl_seconds` race).
- `test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` — flipped to `async: false` (GENUINE `Application.put_env` Mux-config race).
- `test/rindle/storage/local_test.exs` — kept `async: true`; justified `@async_safety_allow [:file_mutation]` (tmp-scoped writes).
- `test/install_smoke/package_metadata_test.exs` — kept `async: true`; justified `@async_safety_allow [:file_mutation]` (unique per-build tmp root).
- 15 conversions (`async: false` -> `async: true`): admin/queries, attach_detach, delivery/streaming_dispatch, domain/migration, ops/variant_maintenance, owner_erasure_batch_boundary, owner_erasure_batch_opts (Integration module only), owner_erasure_batch_proof, owner_erasure_batch, owner_erasure, runtime_status_task, telemetry/emission, upload/resumable_telemetry, workers/ingest_provider_webhook, workers/purge_storage.

## Decisions Made
- **Option A (orchestrator-approved):** resolve the 4 pre-existing offenders in-plan rather than deferring — test-only, within HARD-01's reliability intent.
- **Compiler-warning handling:** added `def __async_safety_allow__/0` referencing the attribute in both annotated modules so `mix compile --warnings-as-errors` stays green (the attribute is consumed by the guard via source AST, never at runtime).
- **Guard integrity:** detector logic untouched — the two SAFE modules opt out explicitly; the two GENUINE races leave the `async: true` set.

## Deviations from Plan

### Auto-fixed / authorized scope expansion

**1. [Rule 1 - Bug / authorized scope] Resolved 4 pre-existing async:true offenders surfaced by the guard**
- **Found during:** Task 1 (guard verify gate)
- **Issue:** The guard correctly flagged 4 `async: true` modules outside the plan's `files_modified` (2 genuine `Application.put_env` races; 2 provably-safe tmp-scoped `File` mutations the static tracker cannot bridge).
- **Fix:** Per orchestrator Option A — `profile_test.exs` + `http_cancel_upload_test.exs` flipped to `async: false`; `local_test.exs` + `package_metadata_test.exs` annotated with justified `@async_safety_allow [:file_mutation]` + explanatory comment.
- **Files modified:** the 4 modules above.
- **Verification:** `mix test test/async_safety_guard_test.exs` GREEN; `mix compile --warnings-as-errors` clean (no unused-attribute warning).
- **Committed in:** `e4e3186` (Task 1 commit)

**2. [Out-of-scope, NOT fixed] Pre-existing docs-parity failure**
- **Found during:** Task 2 full-suite verify
- **Issue:** `test/install_smoke/release_docs_parity_test.exs:319` fails (`running =~ "Package Consumer Proof Matrix"`).
- **Why not fixed:** Confirmed PRE-EXISTING and unrelated — fails identically with all 107-01 changes stashed/reverted, stable across `--seed` (not an async-ordering flake). Stems from the parked `.planning`/docs archive-cleanup working-tree state. Per scope-boundary rules, left untouched and logged in `deferred-items.md`.

---

**Total deviations:** 1 authorized scope expansion (4 module fixes) + 1 out-of-scope pre-existing failure logged, not fixed.
**Impact on plan:** Scope expansion was test-only and squarely within HARD-01 intent; no `lib/` change, no scope creep, no prohibition violated.

## Issues Encountered
- The `@async_safety_allow` module attribute warned as "set but never used" under `--warnings-as-errors` (the guard reads it from source AST, not at runtime). Resolved with a 1-line `def __async_safety_allow__/0` reference in each annotated module.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- HARD-01 complete: async-correctness is now a self-enforcing, merge-blocking gate. Ready for HARD-02..04.
- Carry-forward: the pre-existing `release_docs_parity_test.exs` failure is owned by the parked docs/archive-cleanup change set, not by this phase (see `deferred-items.md`).

## Self-Check: PASSED

- `test/async_safety_guard_test.exs` — FOUND
- `107-01-SUMMARY.md` — FOUND
- `deferred-items.md` — FOUND
- Commit `e4e3186` (Task 1) — FOUND
- Commit `a583040` (Task 2) — FOUND

---
*Phase: 107-reliability-security-dx-hardening*
*Completed: 2026-06-22*
