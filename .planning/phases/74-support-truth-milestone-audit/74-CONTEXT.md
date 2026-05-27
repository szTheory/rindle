# Phase 74: Support Truth & Milestone Audit - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 74 closes v1.15 **support truth** and **milestone audit** (TRUTH-04, AUDIT-01):
fix doc drift in `guides/operations.md` and `Rindle.Upload.TusPlug` moduledoc, then
confirm 6/6 v1.15 requirements and align planning artifacts — with **no new public
feature surface**.

**In scope:**
- TRUTH-04: `guides/operations.md` accurately lists all **nine** shipped Mix tasks;
  `Rindle.Upload.TusPlug` moduledoc scope matches implemented tus extensions and methods.
- TRUTH-04: Extend `test/install_smoke/docs_parity_test.exs` to lock the nine-task index.
- AUDIT-01: Create `.planning/milestones/v1.15-MILESTONE-AUDIT.md` (6/6 requirements, 4 phases).
- AUDIT-01: Align `.planning/REQUIREMENTS.md`, `PROJECT.md`, `STATE.md`, `JTBD-MAP.md`,
  and `.planning/ROADMAP.md` post-ship.

**Out of scope (explicit):**
- `lib/` behavior changes (TusPlug **moduledoc-only** edits allowed).
- `/gsd-complete-milestone` full archive (ROADMAP/requirements archive) unless user
  invokes separately — this phase produces audit + planning alignment, not milestone archive.
- Force-delete, admin UI, second streaming provider, new mix tasks, or tus protocol changes.
- Nyquist work on phases 68–70 (Phase 73).
- CI YAML changes (Phase 71).
- PROOF-06 mix test (Phase 72).

</domain>

<decisions>
## Implementation Decisions

Research sources: assumptions-mode codebase analysis, ROADMAP Phase 74 success criteria,
REQUIREMENTS TRUTH-04/AUDIT-01, Phase 70 TRUTH-03 thin-index precedent, TusPlug source
and tests, v1.13/v1.14 milestone audit templates.

### operations.md — nine Mix tasks (TRUTH-04)

- **D-01:** Change intro from **“six Mix tasks”** to **“nine Mix tasks”** at
  `guides/operations.md` line 3 (and any dependent copy that repeats the count).
- **D-02:** The canonical nine shipped tasks (module names for parity tests):
  1. `mix rindle.abort_incomplete_uploads` → `Mix.Tasks.Rindle.AbortIncompleteUploads`
  2. `mix rindle.backfill_metadata` → `Mix.Tasks.Rindle.BackfillMetadata`
  3. `mix rindle.batch_owner_erasure` → `Mix.Tasks.Rindle.BatchOwnerErasure`
  4. `mix rindle.cleanup_orphans` → `Mix.Tasks.Rindle.CleanupOrphans`
  5. `mix rindle.doctor` → `Mix.Tasks.Rindle.Doctor`
  6. `mix rindle.regenerate_variants` → `Mix.Tasks.Rindle.RegenerateVariants`
  7. `mix rindle.runtime_status` → `Mix.Tasks.Rindle.RuntimeStatus`
  8. `mix rindle.sweep_orphaned_temp_files` → `Mix.Tasks.Rindle.SweepOrphanedTempFiles`
  9. `mix rindle.verify_storage` → `Mix.Tasks.Rindle.VerifyStorage`
- **D-03:** Add **Task Reference** subsections for the three tasks missing today:
  `doctor`, `runtime_status`, `batch_owner_erasure`. Each entry: module name,
  one-line purpose, pointer to `mix help rindle.<task>` / `@moduledoc` as canonical
  contract — **no** flag tables or JSON schema duplication.
- **D-04:** Keep **thin-index** discipline (Phase 5 D-18, Phase 70 D-16/D-18):
  Runtime Diagnostics narrative may remain; Task Reference is the authoritative
  enumeration adopters scan for “what mix tasks exist.”
- **D-05:** **`batch_owner_erasure`** Task Reference stays thin: API names +
  link to [`user_flows.md`](user_flows.md) batch subsection; **no** `--owners-file`,
  `owner_type`, or flag table in `operations.md` (Phase 70 parity refutes).

### TusPlug moduledoc (TRUTH-04)

- **D-06:** Replace stale **Scope (Phase 42)** section with current shipped truth:
  - Advertised `Tus-Extension` set matches `@tus_extensions`:
    `creation,expiration,termination,checksum,creation-defer-length,concatenation`.
  - Methods table: `PATCH` and `DELETE` are **implemented** (remove “Plan 03” and “—” placeholders).
  - Backing: **Local and S3** tus paths shipped (v1.8); remove “ONLY” / “proven against
    Local only” wording.
- **D-07:** **Preserve** accurate deployment constraints: S3 node-local tail buffer,
  sticky-session / node-affinity requirement, `:tus_tail_missing` loud failure on
  misrouted resume — these remain in moduledoc.
- **D-08:** **Moduledoc-only** change in `lib/rindle/upload/tus_plug.ex` — no handler
  or extension behavior changes in this phase.

### docs_parity_test (TRUTH-04)

- **D-09:** Extend `test/install_smoke/docs_parity_test.exs` with a test that asserts
  all nine `mix rindle.<task>` strings appear in `guides/operations.md` and intro
  references nine tasks (not six).
- **D-10:** Optional: assert `TusPlug` moduledoc mentions checksum/concatenation extensions
  if a lightweight string check is stable — **Claude's discretion**; primary gate is
  operations nine-task list.

### Milestone audit (AUDIT-01)

- **D-11:** Create `.planning/milestones/v1.15-MILESTONE-AUDIT.md` following
  `v1.14-MILESTONE-AUDIT.md` structure:
  - Frontmatter: `milestone: v1.15`, `status: passed`, scores 6/6 requirements, 4/4 phases.
  - Requirements table cross-referencing CI-01, CI-02, PROOF-06, VAL-01, TRUTH-04, AUDIT-01.
  - Phase verification summary for phases 71–74 using `*-VERIFICATION.md` under
    `.planning/phases/`.
  - Integration / flow notes where evidence exists (e.g. CI-02 + package-consumer,
    PROOF-06 closes v1.14 operator gap, VAL-01 closes v1.14 Nyquist).
- **D-12:** Mark **TRUTH-04** and **AUDIT-01** `[x]` in `.planning/REQUIREMENTS.md`
  traceability table when audit passes.

### Planning truth alignment (AUDIT-01)

- **D-13:** Update **`.planning/PROJECT.md`**: move v1.15 requirements to Validated;
  refresh Current State / Current Milestone to reflect v1.15 ship (maintenance closure).
- **D-14:** Update **`.planning/STATE.md`**: phase 74 complete; milestone status;
  fix stale “Next: phase 71” / “Executing Phase 73” pointers.
- **D-15:** Update **`.planning/JTBD-MAP.md`**: refresh anchor line to v1.15 + current
  git sha; append “What changed” entry for maintenance/proof-honesty milestone.
- **D-16:** Update **`.planning/ROADMAP.md`**: mark v1.15 milestone shipped in header
  (link to `v1.15-MILESTONE-AUDIT.md`); do **not** run full milestone archive unless
  user invokes `/gsd-complete-milestone` separately.

### Plan structure

- **D-17:** **Two plans:**
  1. **74-01** — TRUTH-04: `operations.md`, TusPlug moduledoc, `docs_parity_test.exs`
  2. **74-02** — AUDIT-01: `v1.15-MILESTONE-AUDIT.md` + planning truth updates (D-12–D-16)

### Claude's Discretion

- Exact Task Reference subsection ordering (group diagnostics vs maintenance vs erasure).
- Whether to add a summary table of nine tasks at top of Task Reference section.
- JTBD-MAP delta detail level for v1.15 (maintenance-only — no new JTBD rows expected).
- ROADMAP phase checkboxes / completion markers beyond milestone header line.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 74 goal and four success criteria
- `.planning/REQUIREMENTS.md` — TRUTH-04, AUDIT-01
- `.planning/PROJECT.md` — v1.15 maintenance charter, support-truth boundary

### TRUTH-04 — doc targets and precedent
- `guides/operations.md` — thin index (fix count + Task Reference gaps)
- `lib/rindle/upload/tus_plug.ex` — moduledoc scope vs `@tus_extensions` / handlers
- `lib/mix/tasks/rindle.*.ex` — nine shipped tasks (`@moduledoc` canonical)
- `test/install_smoke/docs_parity_test.exs` — parity test home (Phase 66/70 pattern)
- `.planning/milestones/v1.14-phases/70-proof-adopter-guidance/70-CONTEXT.md` — D-16/D-18 thin ops pointer
- `.planning/milestones/v1.14-phases/70-proof-adopter-guidance/70-VERIFICATION.md` — TRUTH-03 ops constraints

### Tus implementation truth
- `test/rindle/upload/tus_plug_test.exs` — PATCH/DELETE/concat/checksum coverage
- `test/rindle/upload/tus_s3_integration_test.exs` — S3 tus backing proof

### AUDIT-01 — audit templates and phase evidence
- `.planning/milestones/v1.14-MILESTONE-AUDIT.md` — audit structure precedent
- `.planning/milestones/v1.13-MILESTONE-AUDIT.md` — support-truth milestone close pattern
- `.planning/phases/71-ci-proof-honesty/71-VERIFICATION.md` — CI-01/CI-02 evidence
- `.planning/phases/72-mix-batch-failure-proof/72-VERIFICATION.md` — PROOF-06 evidence
- `.planning/phases/73-nyquist-validation-closure/73-VERIFICATION.md` — VAL-01 evidence
- `.planning/JTBD-MAP.md` — planning truth alignment target
- `.planning/STATE.md` — session/progress alignment target

### Prior phase boundaries (do not reopen)
- `.planning/phases/71-ci-proof-honesty/71-CONTEXT.md` — CI scope
- `.planning/phases/72-mix-batch-failure-proof/72-CONTEXT.md` — PROOF-06 scope
- `.planning/phases/73-nyquist-validation-closure/73-CONTEXT.md` — VAL-01 scope

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Nine `Mix.Tasks.Rindle.*` modules under `lib/mix/tasks/` — authoritative CLI contracts.
- `docs_parity_test.exs` already asserts doctor/runtime_status narrative and batch
  thin-pointer rules — extend, do not duplicate.
- Phase 71–73 `*-VERIFICATION.md` artifacts supply audit evidence without re-running work.

### Established Patterns
- **Thin ops index:** `@moduledoc` canonical; guide cross-links only (Phase 5/70).
- **TRUTH phases:** guide + moduledoc + `docs_parity_test.exs` atomic change.
- **Milestone audit:** `v1.N-MILESTONE-AUDIT.md` with 3-source requirement cross-check.

### Integration Points
- Phase 74 closes v1.15; feeds optional `/gsd-complete-milestone` later.
- No `lib/` API changes expected beyond TusPlug `@moduledoc`.

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without correction (assumptions mode, 2026-05-27).
- Known drift: `operations.md` says six tasks; codebase ships nine; TusPlug moduledoc
  frozen at Phase 42 scope while v1.8 completed PATCH/DELETE/S3/checksum/concatenation.

</specifics>

<deferred>
## Deferred Ideas

- Full `/gsd-complete-milestone` ROADMAP/requirements archive — separate user invocation.
- Making `contract` ExUnit or dialyzer merge-blocking — out of v1.15 charter.
- Force-delete (LIFE-06) — v1.16+ demand-gated.

</deferred>

---

*Phase: 74-support-truth-milestone-audit*
*Context gathered: 2026-05-27*
