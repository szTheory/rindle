# Phase 74: Support Truth & Milestone Audit - Research

**Researched:** 2026-05-27
**Domain:** Documentation parity (TRUTH-04) and milestone closure (AUDIT-01) — no new `lib/` behavior
**Confidence:** HIGH

---

## Summary

Phase 74 closes v1.15 with **support truth** and a **milestone audit**. Implementation is
almost entirely docs + planning artifacts; the only `lib/` touch is TusPlug `@moduledoc`.

Known drift (confirmed in repo):

| Artifact | Drift | Truth source |
|----------|-------|--------------|
| `guides/operations.md` line 3 | Says **six** Mix tasks | Nine `lib/mix/tasks/rindle.*.ex` modules |
| `guides/operations.md` Task Reference | Missing subsections for `doctor`, `runtime_status`, `batch_owner_erasure` | `@moduledoc` on each Mix task |
| `lib/rindle/upload/tus_plug.ex` moduledoc | Phase 42 scope; PATCH/DELETE marked "—" | `@tus_extensions` + handlers/tests |
| `test/install_smoke/docs_parity_test.exs` | No nine-task enumeration gate | Phase 66/70 parity pattern |

Phases 71–73 already have `*-VERIFICATION.md` under `.planning/phases/` — sufficient for
AUDIT-01 evidence without re-running CI or proof work.

**Primary recommendation:** Two execute plans (CONTEXT D-17): **74-01** TRUTH-04 atomic
(docs + moduledoc + parity test), **74-02** AUDIT-01 (v1.15 audit + planning truth).

---

## Nine Shipped Mix Tasks (canonical)

| CLI | Module |
|-----|--------|
| `mix rindle.abort_incomplete_uploads` | `Mix.Tasks.Rindle.AbortIncompleteUploads` |
| `mix rindle.backfill_metadata` | `Mix.Tasks.Rindle.BackfillMetadata` |
| `mix rindle.batch_owner_erasure` | `Mix.Tasks.Rindle.BatchOwnerErasure` |
| `mix rindle.cleanup_orphans` | `Mix.Tasks.Rindle.CleanupOrphans` |
| `mix rindle.doctor` | `Mix.Tasks.Rindle.Doctor` |
| `mix rindle.regenerate_variants` | `Mix.Tasks.Rindle.RegenerateVariants` |
| `mix rindle.runtime_status` | `Mix.Tasks.Rindle.RuntimeStatus` |
| `mix rindle.sweep_orphaned_temp_files` | `Mix.Tasks.Rindle.SweepOrphanedTempFiles` |
| `mix rindle.verify_storage` | `Mix.Tasks.Rindle.VerifyStorage` |

Task Reference today documents: cleanup_orphans, sweep, regenerate, verify_storage,
abort_incomplete_uploads, backfill_metadata — plus narrative for doctor/runtime_status
in Runtime Diagnostics but **no** Task Reference subsections for the three gaps.

---

## TusPlug Moduledoc Truth

From source (`lib/rindle/upload/tus_plug.ex`):

- `@tus_extensions`: `creation,expiration,termination,checksum,creation-defer-length,concatenation`
- PATCH and DELETE handlers implemented (not Plan 03 placeholders)
- S3 tus backing shipped (v1.8); Local + S3 paths — remove "Local only" / "ONLY" wording
- **Preserve** Deployment constraint section (node-local tail, sticky sessions, `:tus_tail_missing`)

Test evidence (no new tests required for moduledoc):

- `test/rindle/upload/tus_plug_test.exs` — PATCH/DELETE/checksum/concat
- `test/rindle/upload/tus_s3_integration_test.exs` — S3 backing

---

## docs_parity_test Extension

Existing tests already assert doctor/runtime_status **narrative** and batch erasure
**thin-pointer** rules (no `--owners-file` in operations.md). Missing:

- Intro says **nine** tasks (not six)
- All nine `mix rindle.<task>` strings present in `guides/operations.md`

Optional (D-10 discretion): TusPlug moduledoc string checks for checksum/concatenation —
only if stable; not blocking.

---

## Milestone Audit (AUDIT-01)

Template: `.planning/milestones/v1.14-MILESTONE-AUDIT.md`

v1.15 requirements (6 total):

| REQ-ID | Phase | Evidence |
|--------|-------|----------|
| CI-01 | 71 | `71-VERIFICATION.md` |
| CI-02 | 71 | `71-VERIFICATION.md` |
| PROOF-06 | 72 | `72-VERIFICATION.md` |
| VAL-01 | 73 | `73-VERIFICATION.md` |
| TRUTH-04 | 74 | 74-01 completion + parity test |
| AUDIT-01 | 74 | `v1.15-MILESTONE-AUDIT.md` + planning alignment |

Planning truth targets (D-12–D-16): REQUIREMENTS.md checkboxes, PROJECT.md validated
section, STATE.md phase pointers, JTBD-MAP anchor, ROADMAP.md milestone header — **not**
full `/gsd-complete-milestone` archive.

---

## Pitfalls

1. **Fat Task Reference** — Do not duplicate `@moduledoc` flag tables (Phase 70 D-18).
   `batch_owner_erasure` stays API names + `user_flows.md` link only.
2. **lib/ behavior** — TusPlug is moduledoc-only; no handler/extension edits.
3. **Premature archive** — ROADMAP/requirements archive deferred unless user runs
   `/gsd-complete-milestone`.
4. **Reopening 71–73** — No CI YAML or new PROOF-06 / VAL-01 work in this phase.

---

## Validation Architecture

`workflow.nyquist_validation` is enabled. Phase 74 adds **new** automated gates via
`docs_parity_test.exs` (TRUTH-04) and ExUnit for existing tus tests (regression only).

### Phase 74 Validation Approach

1. **Plan 74-01:** After doc edits, run
   `mix test test/install_smoke/docs_parity_test.exs` — must exit 0.
2. **Plan 74-01 (optional discretion):** Spot-check moduledoc with
   `mix compile --force` (no warnings from doc edits).
3. **Plan 74-02:** Grep audit file for `6/6` requirements and phase table rows 71–74;
   grep REQUIREMENTS for `[x] **TRUTH-04**` and `[x] **AUDIT-01**`.

### Wave 0 Gaps

None — extend existing `docs_parity_test.exs`; no new test files required unless executor
adds optional TusPlug string test (D-10).

---

## RESEARCH COMPLETE
